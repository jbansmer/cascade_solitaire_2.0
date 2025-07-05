require "pg"

require "pry"

require_relative "./dealer.rb"

class DatabasePersistence
  attr_reader :foundation

  def initialize(logger)
    @deck = Deck.new

    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "cascade")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def all_high_scores
    sql = "SELECT name, high_score FROM players ORDER BY high_score DESC;"
    result = query(sql)

    result.map do |tuple|
      { name: tuple["name"], score: tuple["high_score"] }
    end
  end

  def existing_name?(name)
    names = all_players_names
    names.include?(name)
  end

  def deal_new_game
    reset_game_layout
    @deck.deal_game
    deal_all_piles
    update_playable_cards(@foundation)
  end

  def all_current_pile_cards
    sql = <<~SQL
        SELECT file_name, pile_id, rank, suit FROM play_piles
          ORDER BY CASE
            WHEN suit = 'spades' THEN 1
            WHEN suit = 'hearts' THEN 2
            WHEN suit = 'clubs' THEN 3
            ELSE 4
          END, RANK;
        SQL
    result = query(sql)

    query_to_card_info_hash(result)
  end

  def all_playable_cards
    sql = <<~SQL
        SELECT p.file_name, p.pile_id, p.rank, p.suit FROM play_piles p
          JOIN foundation f
            ON f.rank = p.rank OR f.suit = p.suit;
        SQL
    result = query(sql)

    query_to_card_info_hash(result)
  end

  def current_foundation
    sql = <<~SQL
        SELECT file_name, pile_id, rank, suit FROM foundation
          ORDER BY card_position DESC
          LIMIT 1;
        SQL
    result = query(sql)

    query_to_card_info_hash(result).first
  end

  def current_score
    sql = "SELECT count(id) FROM foundation;"
    result = query(sql)

    result.values.flatten[0]
  end

  def current_high_score(name)
    sql = "SELECT high_score FROM players WHERE name = $1;"
    result = query(sql, name)

    result.values.flatten[0]
  end

  def new_high_score(current_score, name)
    sql = "UPDATE players SET high_score = $1 WHERE name = $2;"
    query(sql, current_score.to_i, name)
  end

  def cards_in_each_play_pile
    sql = <<~SQL
        SELECT count(id), pile_id FROM play_piles
          GROUP BY pile_id;
        SQL
    result = query(sql)

    cards_by_play_pile = { 1 => 0, 2 => 0 }

    result.each do |tuple|
      cards_by_play_pile[tuple["pile_id"].to_i] = tuple["count"].to_i
    end

    return cards_by_play_pile[1], cards_by_play_pile[2]
  end

  def cards_in_each_draw_pile
    sql = <<~SQL
        SELECT count(id), suit_pile FROM draw_piles
          WHERE drawn = false
          GROUP BY suit_pile;
        SQL
    result = query(sql)

    cards_by_suit_pile = { "spades" => 0, "hearts" => 0, "clubs" => 0, "diamonds" => 0 }

    result.each do |tuple|
      cards_by_suit_pile[tuple["suit_pile"]] = tuple["count"].to_i
    end

    return cards_by_suit_pile["spades"], cards_by_suit_pile["hearts"],
           cards_by_suit_pile["clubs"], cards_by_suit_pile["diamonds"]
  end

  def card_playable_to_foundation?(rank, suit)
    foundation = current_foundation
    rank == foundation[:rank] || suit == foundation[:suit]
  end

  def play_card_to_foundation(rank, suit)
    play_card_info = select_card_info(rank, suit)
    remove_from_play_pile(rank, suit)
    add_to_foundation(play_card_info)
    draw_a_card(play_card_info[:pile_id], suit)
  end

  private

  def all_players_names
    sql = "SELECT name from players;"
    result = query(sql)
    result.values.flatten
  end

  def reset_game_layout
    all_pile_relations = ['play_piles',
                          'foundation',
                          'draw_piles'
                         ]

    all_pile_relations.each do |pile|
      query("DELETE FROM #{pile};")
    end
  end

  def deal_all_piles
    draw_piles = { 'spades' => @deck.spades_draw_pile,
                   'hearts' => @deck.hearts_draw_pile,
                   'clubs' => @deck.clubs_draw_pile,
                   'diamonds' => @deck.diamonds_draw_pile
                   }
    draw_piles.each do |suit_draw_pile, cards|
      deal_draw_piles(suit_draw_pile, cards)
    end
    deal_foundation
    deal_play_piles
  end

  def deal_draw_piles(suit_draw_pile, cards)
    sql = "INSERT INTO draw_piles (file_name, suit_pile, rank, suit) VALUES ($1, $2, $3, $4);"

    cards.each do |file_name, rank_suit|
      query(sql, file_name, suit_draw_pile, rank_suit[:rank], rank_suit[:suit])
    end
  end

  def deal_foundation
    sql = "INSERT INTO foundation (file_name, rank, suit) VALUES ($1, $2, $3);"
    
    file_name, rank, suit = foundation_info
    @foundation = {rank: rank, suit: suit}
    query(sql, file_name, rank, suit)
  end

  def deal_play_piles
    sql = "INSERT INTO play_piles (file_name, pile_id, rank, suit) VALUES ($1, 1, $2, $3);"

    @deck.play_pile.each do |file_name, rank_suit|
      query(sql, file_name, rank_suit[:rank], rank_suit[:suit])
    end
  end

  def foundation_info
    file_name = @deck.foundation.keys.first
    rank = @deck.foundation[file_name][:rank]
    suit = @deck.foundation[file_name][:suit]

    return file_name, rank, suit
  end

  def update_playable_cards(foundation)
    sql = <<~SQL
        UPDATE play_piles
          SET playable = $1
          WHERE rank = $2 OR suit = $3;
        SQL

    query(sql, true, foundation[:rank], foundation[:suit])
  end

  def select_card_info(rank, suit)
    sql = <<~SQL
        SELECT file_name, pile_id, rank, suit FROM play_piles
          WHERE rank = $1 AND suit = $2;
        SQL
    result = query(sql, rank, suit)

    query_to_card_info_hash(result).first
  end

  def remove_from_play_pile(rank, suit)
    sql = "DELETE FROM play_piles WHERE rank = $1 AND suit = $2;"
    result = query(sql, rank, suit)
  end

  def add_to_foundation(play_card_info)
    sql = <<~SQL 
        INSERT INTO foundation (file_name, pile_id, rank, suit)
          VALUES ($1, $2, $3, $4);
        SQL

    result = query(sql,
                   play_card_info[:file_name],
                   play_card_info[:pile_id],
                   play_card_info[:rank],
                   play_card_info[:suit]
                  )
  end

  def draw_a_card(current_pile, suit_played)
    draw_card_info = draw_from_suited_draw_pile(suit_played)
    unless draw_card_info.nil?
      add_to_next_play_pile(draw_card_info, current_pile)
      mark_card_drawn(draw_card_info)
    end
  end

  def draw_from_suited_draw_pile(suit_played)
    sql = <<~SQL
        SELECT file_name, rank, suit FROM draw_piles
          WHERE suit_pile = $1 AND drawn = false
          ORDER BY id
          LIMIT 1;
        SQL
    result = query(sql, suit_played)

    query_to_card_info_hash(result).first
  end

  def add_to_next_play_pile(draw_card_info, current_pile)
    next_pile = current_pile.to_i == 1 ? 2 : 1
    sql = <<~SQL
        INSERT INTO play_piles (file_name, pile_id, rank, suit)
          VALUES ($1, $2, $3, $4);
        SQL

    result = query(sql, draw_card_info[:file_name], next_pile, draw_card_info[:rank], draw_card_info[:suit])
  end

  def mark_card_drawn(draw_card_info)
    rank, suit = draw_card_info[:rank], draw_card_info[:suit]
    sql = <<~SQL
        UPDATE draw_piles
          SET drawn = $1
          WHERE rank = $2 AND suit = $3;
        SQL
    result = query(sql, true, rank, suit)
  end

  def query_to_card_info_hash(result)
    result.map do |tuple|
      { file_name: tuple['file_name'],
        pile_id: tuple['pile_id'],
        rank: tuple['rank'],
        suit: tuple['suit']
      }
    end
  end
end
