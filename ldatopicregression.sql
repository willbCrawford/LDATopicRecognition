PGDMP                         x           LDATopicRecognition    12.1    12.0      �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    17486    LDATopicRecognition    DATABASE     �   CREATE DATABASE "LDATopicRecognition" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';
 %   DROP DATABASE "LDATopicRecognition";
                postgres    false            ~           1247    18680    topic_word_assignments    TYPE     d   CREATE TYPE public.topic_word_assignments AS (
	word text COLLATE pg_catalog."C",
	topic integer
);
 )   DROP TYPE public.topic_word_assignments;
       public          postgres    false            �           1247    18652    topic_assignment    TYPE     p   CREATE TYPE public.topic_assignment AS (
	doc_id integer,
	topic_assignments public.topic_word_assignments[]
);
 #   DROP TYPE public.topic_assignment;
       public          postgres    false    638            �            1255    18700    create_and_generate_data()    FUNCTION       CREATE FUNCTION public.create_and_generate_data() RETURNS public.topic_assignment[]
    LANGUAGE plpgsql
    AS $$DECLARE
	word_topic_sql TEXT := 'CREATE TABLE IF NOT EXISTS topic_word(word text PRIMARY KEY,' || string_agg('topic_' || i::text || ' integer, prob_' || i::text || ' double precision', ',') || ');' FROM generate_series(1,2) AS i;
	doc_topic_sql TEXT := 'CREATE TABLE IF NOT EXISTS doc_topic(doc_id integer PRIMARY KEY,' || string_agg('topic_' || i::text || ' integer, prob_' || i::text || ' double precision', ',') || ');' FROM generate_series(1,2) AS i;
	topic_assignments_sql TEXT := 'CREATE TABLE topic_assignments OF topic_assignment';
	insert_word_topic_sql TEXT := 'INSERT INTO topic_word(word,' || string_agg('topic_' || i::text, ', ') || ') SELECT b.word,' || string_agg('SUM(CASE b.topic WHEN ' || i::text || ' THEN 1 ELSE 0 END) AS topic_' || i::text, ',') || ' FROM ( SELECT (UNNEST(a.topic_assignments)).* FROM topic_assignments AS a ) AS b GROUP BY b.word;' FROM generate_series(1, 2) AS i;
	insert_doc_topic_sql TEXT :=  'INSERT INTO doc_topic(doc_id,' || string_agg('topic_' || i::text, ', ') || ') SELECT doc_id,' || string_agg('SUM(CASE topic WHEN ' || i::text || ' THEN 1 ELSE 0 END) AS topic_' || i::text, ',') || ' FROM (SELECT doc_id, (UNNEST(topic_assignments)).* FROM topic_assignments) AS a GROUP BY doc_id;' FROM generate_series(1, 2) AS i;
	temprow_cw corpus_words.word%TYPE;
	temprow_cw_tv corpus.ts_vector%TYPE;
	temprow_c corpus.doc_id%TYPE;
	topic_assignments topic_assignment[];
BEGIN
	EXECUTE topic_assignments_sql;
	INSERT INTO topic_assignments SELECT (UNNEST(get_topic_assignments)).* FROM get_topic_assignments();
	EXECUTE word_topic_sql;
	EXECUTE doc_topic_sql;
	EXECUTE insert_word_topic_sql;
	EXECUTE insert_doc_topic_sql;
	
	RETURN topic_assignments;
END;$$;
 1   DROP FUNCTION public.create_and_generate_data();
       public          postgres    false    646            �            1255    18692    get_random_id()    FUNCTION     �  CREATE FUNCTION public.get_random_id() RETURNS integer
    LANGUAGE plpgsql
    AS $$/* 
	Source: https://www.depesz.com/2007/09/16/my-thoughts-on-getting-random-row
*/
DECLARE
    id_range record;
    reply INT4;
    try INT4 := 0;
BEGIN
    SELECT MIN(topic_id), MAX(topic_id) - MIN(topic_id) + 1 AS range INTO id_range FROM topic_table;
    WHILE ( try < 10000 ) LOOP
        try := try + 1;
        reply := FLOOR( random() * id_range.range) + id_range.min;
        perform topic_id FROM topic_table WHERE topic_id = reply;
        IF found THEN
            RETURN reply;
        END IF;
    END LOOP;
    RAISE EXCEPTION 'something strange happened - no record found in % tries', try;
END;$$;
 &   DROP FUNCTION public.get_random_id();
       public          postgres    false            �            1255    18677    get_topic_assignments()    FUNCTION     U  CREATE FUNCTION public.get_topic_assignments() RETURNS public.topic_assignment[]
    LANGUAGE plpgsql
    AS $$DECLARE
	ta topic_assignment[];
BEGIN
	SELECT
		ARRAY_AGG(topic_assignment)::topic_assignment[] AS topic_assignments
		INTO ta
	FROM (
		SELECT
			(e.doc_id, ARRAY_AGG(e.word_topic)::word_topic[])::topic_assignment as topic_assignment
		FROM (
			SELECT
				d.doc_id, (d.lexeme, d.topic_assignment)::word_topic AS word_topic
			FROM (
				SELECT
					c.doc_id, c.lexeme, get_random_id() AS topic_assignment
				FROM (
					SELECT
						b.doc_id, b.lexeme, UNNEST(b.positions) AS position
					FROM (
						SELECT
							a.doc_id, (UNNEST(a.ts_vector)).*
						FROM (
							SELECT
								doc_id, ts_vector
							FROM
								corpus
						) AS a
					) AS b
				) AS c
			) AS d
		) AS e
		GROUP BY
			e.doc_id
	) AS f;
	
	RETURN ta;
END$$;
 .   DROP FUNCTION public.get_topic_assignments();
       public          postgres    false    646            �            1255    18703    lda_regression()    FUNCTION     �  CREATE FUNCTION public.lda_regression() RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
	topic_assignments topic_assignment[];
	topic_assignment topic_assignment;
	i integer := 1000;
	alpha double precision := 0.1;
	eta double precision := 0.001;
BEGIN
	SELECT
		get_topic_assignments 
	INTO 
		topic_assignments 
	FROM 
		get_topic_assignments();
		
	WHILE i < 0
	LOOP
		FOR topic_assignment IN SELECT UNNEST(topic_assignments)
		LOOP
		END LOOP;
		i := i - 1;
	END LOOP;
END;$$;
 '   DROP FUNCTION public.lda_regression();
       public          postgres    false            �            1255    18620    word_topic_generation()    FUNCTION     E  CREATE FUNCTION public.word_topic_generation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE 
	word_topic_sql TEXT := 'CREATE TABLE word_topic(word text PRIMARY KEY,' || string_agg('topic_' || i::text || ' integer', ',') || ');' FROM generate_series(1,2) AS i;
	doc_topic_sql TEXT := 'CREATE TABLE doc_topic(doc_id integer PRIMARY KEY,' || string_agg('topic_' || i::text || ' integer', ',') || ');' FROM generate_series(1,2) AS i;
	insert_word_topic_sql TEXT := 'SELECT b.word,' || string_agg('SUM(CASE b.topic WHEN ' || i::text || ' THEN 1 ELSE 0 END) AS topic_' || i::text, ',') || ' FROM ( SELECT (UNNEST(a.topic_assignments)).* FROM ( SELECT (UNNEST(get_topic_assignments)).* FROM topic_assignments ) AS a ) AS b GROUP BY b.word;' FROM generate_series(1, 2) AS i;
	insert_doc_topic_sql TEXT := 'SELECT a.doc_id,' || string_agg('SUM(a.topic_' || i::text || ') AS topic_' || i::text, ',') || ' FROM (SELECT a.doc_id, a.lexeme,' || string_agg('b.topic_' || i::text, ',') || ' FROM (SELECT doc_id, (UNNEST(ts_vector)).* FROM corpus) AS a, (' || replace(insert_word_topic_sql, ';', ')') || ' AS a GROUP BY a.doc_id;' FROM generate_series(1, 2) AS i;
	temprow_cw corpus_words.word%TYPE;
	temprow_cw_tv corpus.ts_vector%TYPE;
	temprow_c corpus.doc_id%TYPE;
	topic_assignments topic_assignment[];
	succeed BOOLEAN := t;
BEGIN
	SELECT get_topic_assignments INTO topic_assignments FROM get_topic_assignments();
	EXECUTE word_topic_sql;
	EXECUTE doc_topic_sql;
	EXECUTE 'INSERT INTO word_topic ' || insert_word_topic_sql;
	EXECUTE 'INSERT INTO doc_topic ' || insert_doc_topic_sql;
	
	RETURN NEW;
END;$$;
 .   DROP FUNCTION public.word_topic_generation();
       public          postgres    false            �            1259    17487    corpus    TABLE     p   CREATE TABLE public.corpus (
    doc_id integer NOT NULL,
    doc_text text NOT NULL,
    ts_vector tsvector
);
    DROP TABLE public.corpus;
       public         heap    postgres    false            �            1259    18634    corpus_words    TABLE     f   CREATE TABLE public.corpus_words (
    id integer NOT NULL,
    word text,
    frequencies integer
);
     DROP TABLE public.corpus_words;
       public         heap    postgres    false            �            1259    18632    corpus_words_id_seq    SEQUENCE     �   CREATE SEQUENCE public.corpus_words_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.corpus_words_id_seq;
       public          postgres    false    204            �           0    0    corpus_words_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.corpus_words_id_seq OWNED BY public.corpus_words.id;
          public          postgres    false    203            �            1259    19160 	   doc_topic    TABLE     �   CREATE TABLE public.doc_topic (
    doc_id integer NOT NULL,
    topic_1 integer,
    prob_1 double precision,
    topic_2 integer,
    prob_2 double precision
);
    DROP TABLE public.doc_topic;
       public         heap    postgres    false            �            1259    19146    topic_assignments    TABLE     B   CREATE TABLE public.topic_assignments OF public.topic_assignment;
 %   DROP TABLE public.topic_assignments;
       public         heap    postgres    false    638    646            �            1259    18896    topic_table    TABLE     j   CREATE TABLE public.topic_table (
    topic_id integer NOT NULL,
    topic_name character varying(255)
);
    DROP TABLE public.topic_table;
       public         heap    postgres    false            �            1259    19152 
   topic_word    TABLE     �   CREATE TABLE public.topic_word (
    word text NOT NULL,
    topic_1 integer,
    prob_1 double precision,
    topic_2 integer,
    prob_2 double precision
);
    DROP TABLE public.topic_word;
       public         heap    postgres    false                       2604    18637    corpus_words id    DEFAULT     r   ALTER TABLE ONLY public.corpus_words ALTER COLUMN id SET DEFAULT nextval('public.corpus_words_id_seq'::regclass);
 >   ALTER TABLE public.corpus_words ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    204    203    204            �          0    17487    corpus 
   TABLE DATA           =   COPY public.corpus (doc_id, doc_text, ts_vector) FROM stdin;
    public          postgres    false    202   �4       �          0    18634    corpus_words 
   TABLE DATA           =   COPY public.corpus_words (id, word, frequencies) FROM stdin;
    public          postgres    false    204   X5       �          0    19160 	   doc_topic 
   TABLE DATA           M   COPY public.doc_topic (doc_id, topic_1, prob_1, topic_2, prob_2) FROM stdin;
    public          postgres    false    210   �5       �          0    19146    topic_assignments 
   TABLE DATA           F   COPY public.topic_assignments (doc_id, topic_assignments) FROM stdin;
    public          postgres    false    208   �5       �          0    18896    topic_table 
   TABLE DATA           ;   COPY public.topic_table (topic_id, topic_name) FROM stdin;
    public          postgres    false    207   6       �          0    19152 
   topic_word 
   TABLE DATA           L   COPY public.topic_word (word, topic_1, prob_1, topic_2, prob_2) FROM stdin;
    public          postgres    false    209   26       �           0    0    corpus_words_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.corpus_words_id_seq', 4, true);
          public          postgres    false    203                       2606    17494    corpus corpus_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.corpus
    ADD CONSTRAINT corpus_pkey PRIMARY KEY (doc_id);
 <   ALTER TABLE ONLY public.corpus DROP CONSTRAINT corpus_pkey;
       public            postgres    false    202                       2606    18642    corpus_words corpus_words_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.corpus_words
    ADD CONSTRAINT corpus_words_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.corpus_words DROP CONSTRAINT corpus_words_pkey;
       public            postgres    false    204            "           2606    19164    doc_topic doc_topic_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.doc_topic
    ADD CONSTRAINT doc_topic_pkey PRIMARY KEY (doc_id);
 B   ALTER TABLE ONLY public.doc_topic DROP CONSTRAINT doc_topic_pkey;
       public            postgres    false    210                       2606    18900    topic_table topic_table_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.topic_table
    ADD CONSTRAINT topic_table_pkey PRIMARY KEY (topic_id);
 F   ALTER TABLE ONLY public.topic_table DROP CONSTRAINT topic_table_pkey;
       public            postgres    false    207                        2606    19159    topic_word topic_word_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.topic_word
    ADD CONSTRAINT topic_word_pkey PRIMARY KEY (word);
 D   ALTER TABLE ONLY public.topic_word DROP CONSTRAINT topic_word_pkey;
       public            postgres    false    209            �   I   x�3�L�OW bNu �ne�c�eę�X� Ĝ�@"f�E�3�1Q��5�2ᄩ��
Ve� 3��+F��� ��      �      x�3�L�O�4�2�LN,�1z\\\ 2�       �   )   x�3�4���4\&`
,�e�i b�؆q��=... ��	      �   ;   x�3�V�HN,�1�T���J�O�1�T��2��5B��������j�A�X���qqq M�!
      �      x�3�,�/�L�7�2����b���� _7�      �   #   x�K�O�4���4\ɉ%�� ������� �F�     