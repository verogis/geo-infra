import os
import pytoml
import sys

from collections import namedtuple
from os.path import exists, realpath

from generate_utils import path


ConfigFileErrors = namedtuple('ConfigFileErrors', 'base file errors')
'''Store errors of a config file.

Args:
    base (str): The name of the file against which the config is checked.
    file (str): The config file that is checked for errors.
    errors (List[Union[ConfigSectionErrors, ConfigErrors]]): The list of found errors.
'''
ConfigSectionErrors = namedtuple('ConfigSectionErrors', 'section errors')
'''Store errors found in a section of a config file.

Args:
    section (str): the section name in which the errors are found.
    errors (List[str]): the list of found errors.
'''
ConfigErrors = namedtuple('ConfigErrors', 'header errors')
'''Store the configuration errors.

Args:
    header (str): a message to print before the errors.
    errors (List[str]): the list of found errors.
'''


class GenerateConfig:
    '''Read the config files and provide access to the generated config with a dict like interface.

    Args:
        type (str): the type for which to generate the configuration. Default: None.
        portal (str): portal for which to generate the configuration. Default: None.
    '''

    #: Optional keys in the configuration. If one of these keys is missing, no warning is reported.
    optional_values = {
        'front.default_values': set(['wms_list', 'wmts_list']),
    }

    def __init__(self, type=None, portal=None, infra_dir=None):
        self.type = type
        self.portal = portal
        # This variable is used in path where None is not allowed.
        self.infra_dir = infra_dir or ''
        self._current_base_file = None
        self._current_file = None
        self._config = {}
        self.errors = []
        self._load_config()

    def create_output_dirs(self):
        '''Create all the directories for mapinfra's output.

        These directories correspond to the dest section of the config. Keys that start with
        '_template' and the geo_front3 subsection are ignored.
        '''
        for key, folder in self._config['dest'].items():
            # We don't have to create the dirs for keys associated with geo_front3 (in config.dest)
            if not isinstance(folder, dict) and \
                    not key.startswith('template_') and \
                    not exists(folder):
                os.makedirs(folder, exist_ok=True)

    def _load_config(self):
        '''Load the configuration and store it into self._config.

        It will:

        #. Load the global configuration
        #. Load the configuration common to all portal:

            #. the _common.dist.toml file
            #. the _common.prod.toml file if it exists
            #. the _common.dev.toml file if ``self.type == 'dev'`` and if it exists

        #. Load the portal specific configuration if ``self.portal is not None``. It follows the
           same rules as the common file (dist -> prod -> dev).
        #. Add any complementary keys to self._config that are not in the config files:

            - type
            - portal
            - prod (bool)
            - infra_dir: the absolute path to the current customer infra dir
        '''
        global_config = self._load_config_from_file('config/global.toml')
        self._update_config(self._config, global_config, section_check=False)

        common_config = self._load_config_from_file('_common', prefix=self.infra_dir, must_exists=False)
        config_section_errors = ConfigSectionErrors(section='common', errors=[])
        self._update_config(
            self._config,
            common_config,
            section_check=False,
            errors=config_section_errors.errors)
        self.errors.append(config_section_errors)

        if self.portal is not None:
            portal_config = self._load_config_from_file(self.portal, portal_file=True, prefix=self.infra_dir)
            config_section_errors = ConfigSectionErrors(section=self.portal, errors=[])
            self._update_config(
                self._config,
                portal_config,
                section_check=False,
                errors=config_section_errors.errors)
            self.errors.append(config_section_errors)

        self._display_errors()

        self._config['type'] = self.type
        self._config['portal'] = self.portal
        self._config['prod'] = self.type == 'prod'
        # Make output path absolute
        self._config['infra_dir'] = realpath(self.infra_dir)

    def _load_config_from_file(self, cfg_file, portal_file=False, prefix='', must_exists=True):
        '''Load the config file and override keys with those from prod or dev if needed.

        Args:
            cfg_file (str): either a path to an existing file or a category of files, eg _common.
            protal_file (bool): if true, the config file will be checked against
                _template.dist.toml.
        '''
        try:
            dist = self._load_config_file(cfg_file, prefix=prefix)
        except FileNotFoundError as e:
            if must_exists:
                raise e
            else:
                dist = {}

        self._format_templates(dist)
        if portal_file:
            self._check_portal_config_with_portal_template(dist)

        if exists(self._get_config_path(cfg_file, type='prod', prefix=prefix)):
            prod = self._load_config_file(cfg_file, type='prod', prefix=prefix)
            self._format_templates(prod)
            config_file_errors = self._new_config_file_errors()
            self._update_config(dist, prod, errors=config_file_errors.errors)
            self.errors.append(config_file_errors)

        if self.type == 'dev' and exists(self._get_config_path(cfg_file, type='dev', prefix=prefix)):
            dev = self._load_config_file(cfg_file, type='dev', prefix=prefix)
            self._format_templates(dev)
            config_file_errors = self._new_config_file_errors()
            self._update_config(dist, dev, errors=config_file_errors.errors)
            self.errors.append(config_file_errors)

        return dist

    def _load_config_file(self, cfg_file, type='dist', prefix=''):
        '''Load the file from the disk and parse it with the toml module.
        '''
        if exists(cfg_file):
            cfg_path = cfg_file
        else:
            cfg_path = self._get_config_path(cfg_file, type=type, prefix=prefix)

        if type == 'dist':
            self._current_base_file = cfg_path
        else:
            self._current_file = cfg_path

        with open(cfg_path, 'r') as cfg:
            return pytoml.load(cfg)

    def _get_config_path(self, cfg_file, type='dist', prefix=''):
        '''Transform a catogory of file like _common into an actual path we can open.

        Args:
            cfg_file (str): category of file.
            type (str): type of file to get (dest, dev or prod).
        '''
        ext = '.{type}.toml'.format(type=type)
        return path(prefix, 'config', type, cfg_file, ext=ext)

    def _format_templates(self, locations):
        '''Replace {type} and {portal} by their value in each list or dict it finds.
        '''
        for key, value in locations.items():
            if isinstance(value, str):
                locations[key] = self._format_template(value)
            elif isinstance(value, list):
                for index, list_value in enumerate(value):
                    value[index] = self._format_template(list_value)
            elif isinstance(value, dict):
                self._format_templates(value)

    def _format_template(self, location):
        '''Replace the {type} and {portal} by their value.
        '''
        if isinstance(location, str):
            return location.format(
                type=self.type,
                portal=self.portal,
                infra_dir=self.infra_dir)
        else:
            return location

    def _update_config(self, dest, src, depth=0, section_check=True, section=None, errors=None):
        '''Recursively update a dict while checking for inconsistancies.

        Args:
            dest (dict): the destination dict.
            src (dict): the source dict.
            depth (int): the current level of recursivity. Default: 0.
            section_check (bool): whether or not to check for new config sections or new keys. If
                ``depth == 0`` it will report the additions as sections. If ``depth > 0`` it will
                report the additions as keys. Default: True.
            section (str): the name of the current section. Used to provide a more hepful message
                in case of errors. Default: None.
            errors (list): the list of found errors. Default: None.
        '''
        self._check_config(
            dest,
            src,
            depth=depth,
            section_check=section_check,
            section=section,
            errors=errors)

        for key, value in src.items():
            depth += 1
            self._check_value_type(key, value, dest, errors=errors)

            if isinstance(value, dict):
                if section:
                    current_section = '{section}.{subsection}'.format(section=section, subsection=key)
                else:
                    current_section = key

                self._update_config(
                    dest.setdefault(key, {}),
                    value,
                    depth=depth,
                    section_check=section_check,
                    section=current_section,
                    errors=errors)
            else:
                dest[key] = value

    def _check_config(self, dest, src, depth=0, section_check=True, section=None, errors=None):
        '''Check that the source is coherent with the destination. If incoherences are found, they
        are reported.

        Args:
            dest (dict): the destination dict.
            src (dict): the source dict.
            depth (int): the current level of recursivity. Default: 0.
            section_check (bool): whether or not to check for new config sections or new keys. If
                ``depth == 0`` it will report the additions as sections. If ``depth > 0`` it will
                report the additions as keys. Default: True.
            section (str): the name of the current section. Used to provide a more hepful message
                in case of errors. Default: None.
            errors (list): the list of found errors. Default: None.
        '''
        if errors is None:
            errors = []

        if len(dest) != 0:
            if depth == 0:
                if not all([isinstance(value, dict) for value in src.values()]):
                    top_level_keys = [key for key, value in src.items()
                                      if not isinstance(value, dict)]
                    errors.append(ConfigErrors(
                        header='Adding global keys (All keys should be in a section)',
                        errors=top_level_keys))
                if 'src' in src:
                    errors.append(ConfigErrors(
                        header='Modifying global src section. Keys to be changed',
                        errors=src['src'].keys()))
                if 'dest' in src:
                    errors.append(ConfigErrors(
                        header='Modifying global dest section. Keys to be changed',
                        errors=src['dest'].keys()))
                if 'print' in src:
                    if 'mapHeight' in src['print']:
                        errors.append(
                            ConfigErrors(header='Modifying print.mapHeight',
                            errors=[src['print']['mapHeight']]))
                    if 'mapWidth' in src['print']:
                        errors.append(ConfigErrors(
                            header='Modifying print.mapWidth',
                            errors=[src['print']['mapWidth']]))

            if section_check and depth == 0:
                dist_sections = set(dest.keys())
                src_sections = set(src.keys())
                if not src_sections.issubset(dist_sections):
                    added_sections = [section_name for section_name in src_sections - dist_sections
                                      if isinstance(src[section_name], dict)]
                    if added_sections:
                        errors.append(ConfigErrors(
                            header='Adding sections',
                            errors=added_sections))

            if depth > 0 and section_check:
                dist_keys = set(dest.keys())
                src_keys = set(src.keys())
                if section in self.optional_values:
                    src_keys -= self.optional_values[section]

                if not src_keys.issubset(dist_keys):
                    errors.append(ConfigErrors(
                        header='Adding keys (section: {})'.format(section),
                        errors=src_keys - dist_keys))

    def _check_value_type(self, src_key, src_value, dest, errors=None):
        '''Verify that to the source key correspond a value with the same type as the dest value
        for this key.

        Args:
            src_key (str): the source key.
            src_value (any): the sourve value.
            dest (dict): the destination dict.
            errors (list): the list of found errors. Default: None.
        '''
        if errors is None:
            errors = []

        if src_key in dest and not type(src_value) == type(dest[src_key]):
            cfg_errors = ConfigErrors(
                header='Changing the type of key',
                errors=['{} from {} to {}'.format(src_key, type(dest[src_key]), type(src_value))])
            errors.append(cfg_errors)

    def _new_config_file_errors(self):
        '''Returns a new ConfigFileErrors instance based on the current file.
        '''
        return ConfigFileErrors(base=self._current_base_file, file=self._current_file, errors=[])

    def _check_portal_config_with_portal_template(self, portal_config):
        '''Verify that a portal configuration file is coherent with the template.
        '''
        template_config_path = 'config/_template.dist.toml'
        template_config = self._load_config_file(template_config_path)
        # Override with client specific template if it exists
        custom_template_config_path = path(
            self._config['src']['base_include'],
            'config/_template.dist.toml')
        if exists(custom_template_config_path):
            template_config = self._load_config_file(custom_template_config_path)
        config_file_errors = ConfigFileErrors(
            base=template_config_path,
            file=self._get_config_path(self.portal),
            errors=[])
        self.errors.append(config_file_errors)
        self._update_config(template_config, portal_config, errors=config_file_errors.errors)

    def _display_errors(self):
        '''Display all the found errors for each config file on stderr.
        '''
        for config_file_errors in self.errors:
            if config_file_errors.errors:
                if isinstance(config_file_errors, ConfigFileErrors):
                    self._display_config_file_errors(config_file_errors)
                elif isinstance(config_file_errors, ConfigSectionErrors):
                    self._display_config_section_errors(config_file_errors)

    def _display_config_file_errors(self, config_file_errors):
        '''Display the errors of one config file on stderr.
        '''
        message = 'ERRORS between the base "{base}" and the file "{file}"'\
            .format(base=config_file_errors.base, file=config_file_errors.file)
        print(message, file=sys.stderr)

        for config_errors in config_file_errors.errors:
            self._display_config_errors(config_errors)

        print('', file=sys.stderr)

    def _display_config_errors(self, config_errors):
        '''Display the errors on stderr'
        '''
        if config_errors.header:
            print('* {header}'.format(header=config_errors.header), file=sys.stderr)

        for error in config_errors.errors:
            print('** ERROR: {error}'.format(error=error), file=sys.stderr)

    def _display_config_section_errors(self, config_section_errors):
        '''Display the config section errors on stderr.
        '''
        message = 'ERRORS while merging the file from the "{}" category in the main configuration'\
            .format(config_section_errors.section)
        print(message, file=sys.stderr)

        for config_errors in config_section_errors.errors:
            self._display_config_errors(config_errors)

        print('', file=sys.stderr)

    @property
    def config(self):
        '''Access to the row config dict.
        '''
        return self._config

    def get(self, *args, **kwargs):
        '''Forward to self.config.get
        '''
        return self._config.get(*args, **kwargs)

    def __getitem__(self, key):
        if key not in self._config:
            print(key)
            return
        return self._config[key]

    def __setitem__(self, key, value):
        self._config[key] = value

    def __str__(self):
        return str(self._config)

    def __repr__(self):
        return str(self)
