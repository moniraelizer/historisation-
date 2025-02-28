-- créer une logique d'historisation dans une base de données PostgreSQL

CREATE SEQUENCE public.sequence_de_suivi_base_id
INCREMENT 1
START 1
MINVALUE 1
MAXVALUE 1000000;

ALTER SEQUENCE public.sequence_de_suivi_base_id OWNER TO postgres;


--

CREATE TABLE public.suivi_base (
    id integer NOT NULL DEFAULT nextval('"sequence_de_suivi_base_id"'::regclass),
    schema character varying(15) NOT NULL,
    nomtable character varying(50) NOT NULL,
    utilisateur character varying(25),
    dateheure timestamp NOT NULL DEFAULT localtimestamp,
    action character varying(1) NOT NULL CHECK (action IN ('I','D','U')),
    dataorigine text,
    datanouvelle text,
    detailmaj text,
    idobjet integer,
    CONSTRAINT "pk_suivi_base" PRIMARY KEY (id)
) TABLESPACE pg_default;

ALTER TABLE public.suivi_base OWNER to postgres;

-- 

CREATE INDEX index_suivi_base_nomtable ON public.suivi_base(((schema||'.'||nomtable)::TEXT));
CREATE INDEX index_suivi_base_dateheure ON public.suivi_base(dateheure);
CREATE INDEX index_suivi_base_action ON public.suivi_base(action);
CREATE INDEX index_suivi_base_idobjet ON public.suivi_base(idobjet);

-- 

CREATE OR REPLACE FUNCTION public.fonction_suivi_base_maj()
RETURNS TRIGGER AS $body$
DECLARE
    variable_ancienne_valeur TEXT;
    variable_nouvelle_valeur TEXT;
    identifiant INTEGER;
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        variable_ancienne_valeur := ROW(OLD.*);
        variable_nouvelle_valeur := ROW(NEW.*);
        identifiant := OLD.id;
        INSERT INTO public.suivi_base (schema, nomtable, utilisateur, action, dataorigine, datanouvelle, detailmaj, idobjet)
        VALUES (TG_TABLE_SCHEMA::TEXT, TG_TABLE_NAME::TEXT, session_user::TEXT, substring(TG_OP,1,1), variable_ancienne_valeur, variable_nouvelle_valeur, current_query(), identifiant);
        RETURN NEW;

    ELSIF (TG_OP = 'DELETE') THEN
        variable_ancienne_valeur := ROW(OLD.*);
        identifiant := OLD.id;
        INSERT INTO public.suivi_base (schema, nomtable, utilisateur, action, dataorigine, detailmaj, idobjet)
        VALUES (TG_TABLE_SCHEMA::TEXT, TG_TABLE_NAME::TEXT, session_user::TEXT, substring(TG_OP,1,1), variable_ancienne_valeur, current_query(), identifiant);
        RETURN OLD;

    ELSIF (TG_OP = 'INSERT') THEN
        variable_nouvelle_valeur := ROW(NEW.*);
        identifiant := NEW.id;
        INSERT INTO public.suivi_base (schema, nomtable, utilisateur, action, datanouvelle, detailmaj, idobjet)
        VALUES (TG_TABLE_SCHEMA::TEXT, TG_TABLE_NAME::TEXT, session_user::TEXT, substring(TG_OP,1,1), variable_nouvelle_valeur, current_query(), identifiant);
        RETURN NEW;

    ELSE
        RAISE WARNING '[public.fonction_suivi_base_maj] - Other action occurred: %, at %', TG_OP, now();
        RETURN NULL;
    END IF;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public;

-- 

CREATE TRIGGER trigger_suivi_de_la_base
AFTER INSERT OR UPDATE OR DELETE ON commune
FOR EACH ROW EXECUTE PROCEDURE public.fonction_suivi_base_maj();