CREATE TABLE players (
  id serial PRIMARY KEY,
  name text UNIQUE NOT NULL,
  high_score integer
);

CREATE TABLE play_piles (
  id serial PRIMARY KEY,
  file_name text UNIQUE NOT NULL,
  pile_id integer NOT NULL,
  CHECK (pile_id BETWEEN 1 AND 2),
  rank integer NOT NULL,
  suit text NOT NULL,
  playable boolean DEFAULT false
);

CREATE TABLE foundation (
  id serial PRIMARY KEY,
  file_name text UNIQUE NOT NULL,
  rank integer NOT NULL,
  suit text NOT NULL,
  card_position serial NOT NULL,
  pile_id integer NOT NULL DEFAULT 0
);

CREATE TABLE draw_piles (
  id serial PRIMARY KEY,
  file_name text UNIQUE NOT NULL,
  suit_pile text NOT NULL,
  drawn boolean DEFAULT false,
  rank integer NOT NULL,
  suit text NOT NULL
);
