--
-- run this script with DEFAULT_DB_OWNER
--

-- ALTER DATABASE sit_dev
--  SET search_path = userdata, public, postgis, topology, pg_catalog;

 GRANT ALL ON SCHEMA userdata TO DEFAULT_DB_OWNER;
 GRANT ALL ON SCHEMA api3 TO DEFAULT_DB_OWNER;
 GRANT ALL ON SCHEMA features TO DEFAULT_DB_OWNER;
 GRANT ALL ON SCHEMA search TO DEFAULT_DB_OWNER;
 GRANT ALL ON SCHEMA public TO DEFAULT_DB_OWNER WITH GRANT OPTION;
 GRANT ALL ON SCHEMA topology TO DEFAULT_DB_OWNER WITH GRANT OPTION;
 GRANT SELECT, REFERENCES, TRIGGER ON TABLE public.spatial_ref_sys TO DEFAULT_DB_OWNER;
 GRANT SELECT, UPDATE, INSERT, DELETE, REFERENCES, TRIGGER ON TABLE public.geography_columns TO DEFAULT_DB_OWNER;
 GRANT SELECT, UPDATE, INSERT, DELETE, REFERENCES, TRIGGER ON TABLE public.geometry_columns TO DEFAULT_DB_OWNER;
 GRANT SELECT, UPDATE, INSERT, DELETE, REFERENCES, TRIGGER ON TABLE public.raster_columns TO DEFAULT_DB_OWNER;
 GRANT SELECT, UPDATE, INSERT, DELETE, REFERENCES, TRIGGER ON TABLE public.raster_overviews TO DEFAULT_DB_OWNER;

 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA topology TO DEFAULT_DB_OWNER;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA topology TO DEFAULT_DB_OWNER;


-- mapserver user
-- Read Only access on public & userdata

 REVOKE ALL ON SCHEMA public FROM DEFAULT_DB_MAPSERVER_ROLE;
 GRANT USAGE ON SCHEMA public TO DEFAULT_DB_MAPSERVER_ROLE;
 REVOKE ALL ON ALL TABLES IN SCHEMA public FROM DEFAULT_DB_MAPSERVER_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO DEFAULT_DB_MAPSERVER_ROLE;
 REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM DEFAULT_DB_MAPSERVER_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO DEFAULT_DB_MAPSERVER_ROLE;

 REVOKE ALL ON SCHEMA topology FROM DEFAULT_DB_MAPSERVER_ROLE;
 GRANT USAGE ON SCHEMA topology TO DEFAULT_DB_MAPSERVER_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA topology TO DEFAULT_DB_MAPSERVER_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA topology TO DEFAULT_DB_MAPSERVER_ROLE;

 REVOKE ALL ON SCHEMA userdata FROM DEFAULT_DB_MAPSERVER_ROLE;
 GRANT USAGE ON SCHEMA userdata TO DEFAULT_DB_MAPSERVER_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA userdata TO DEFAULT_DB_MAPSERVER_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA userdata TO DEFAULT_DB_MAPSERVER_ROLE;


-- Sphinx searchd user
-- Access Read Only everything

 REVOKE ALL ON SCHEMA public FROM DEFAULT_DB_SEARCH_ROLE;
 GRANT USAGE ON SCHEMA public TO DEFAULT_DB_SEARCH_ROLE;
 REVOKE ALL ON ALL TABLES IN SCHEMA public FROM DEFAULT_DB_SEARCH_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO DEFAULT_DB_SEARCH_ROLE;
 REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM DEFAULT_DB_SEARCH_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO DEFAULT_DB_SEARCH_ROLE;

 REVOKE ALL ON SCHEMA topology FROM DEFAULT_DB_SEARCH_ROLE;
 GRANT USAGE ON SCHEMA topology TO DEFAULT_DB_SEARCH_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA topology TO DEFAULT_DB_SEARCH_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA topology TO DEFAULT_DB_SEARCH_ROLE;

 REVOKE ALL ON SCHEMA search FROM DEFAULT_DB_SEARCH_ROLE;
 GRANT USAGE ON SCHEMA search TO DEFAULT_DB_SEARCH_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA search TO DEFAULT_DB_SEARCH_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA search TO DEFAULT_DB_SEARCH_ROLE;

 REVOKE ALL ON SCHEMA userdata FROM DEFAULT_DB_SEARCH_ROLE;
 GRANT USAGE ON SCHEMA userdata TO DEFAULT_DB_SEARCH_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA userdata TO DEFAULT_DB_SEARCH_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA userdata TO DEFAULT_DB_SEARCH_ROLE;


-- API3 user
-- Access Read Only api3 + features + userdata ro

 REVOKE ALL ON SCHEMA public FROM DEFAULT_DB_API_ROLE;
 GRANT USAGE ON SCHEMA public TO DEFAULT_DB_API_ROLE;
 REVOKE ALL ON ALL TABLES IN SCHEMA public FROM DEFAULT_DB_API_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO DEFAULT_DB_API_ROLE;
 REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM DEFAULT_DB_API_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO DEFAULT_DB_API_ROLE;

 REVOKE ALL ON SCHEMA topology FROM DEFAULT_DB_API_ROLE;
 GRANT USAGE ON SCHEMA topology TO DEFAULT_DB_API_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA topology TO DEFAULT_DB_API_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA topology TO DEFAULT_DB_API_ROLE;

 REVOKE ALL ON SCHEMA api3 FROM DEFAULT_DB_API_ROLE;
 GRANT USAGE ON SCHEMA api3 TO DEFAULT_DB_API_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA api3 TO DEFAULT_DB_API_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api3 TO DEFAULT_DB_API_ROLE;

 GRANT SELECT, UPDATE, INSERT, DELETE, REFERENCES, TRIGGER ON TABLE api3.url_shortener TO DEFAULT_DB_API_ROLE;
 GRANT SELECT, UPDATE, INSERT, DELETE, REFERENCES, TRIGGER ON TABLE api3.files TO DEFAULT_DB_API_ROLE;

 REVOKE ALL ON SCHEMA userdata FROM DEFAULT_DB_API_ROLE;
 GRANT USAGE ON SCHEMA userdata TO DEFAULT_DB_API_ROLE;
 GRANT SELECT, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA userdata TO DEFAULT_DB_API_ROLE;
 GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA userdata TO DEFAULT_DB_API_ROLE;
