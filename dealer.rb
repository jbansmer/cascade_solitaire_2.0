class Cards
  def initialize
    @cards = Dir.glob("public/cards/*").map! { |file| File.basename(file, ".png") }
  end

  def shuffle
    @cards.reject { |card| card == 'back' || card == 'blank' }.shuffle
  end
end

class Deck
  attr_reader :deck, :spades_draw_pile, :hearts_draw_pile, :clubs_draw_pile, :diamonds_draw_pile,
              :foundation, :play_pile
   
  def initialize
    reset
  end

  def reset
    @deck = Cards.new.shuffle
    @spades_draw_pile = {}
    @hearts_draw_pile = {}
    @clubs_draw_pile = {}
    @diamonds_draw_pile = {}
    @foundation = {}
    @play_pile = {}
  end

  def deal
    deck.shift
  end

  def deal_game
    reset

    10.times do |_|
      one_card_to(spades_draw_pile)
      one_card_to(hearts_draw_pile)
      one_card_to(clubs_draw_pile)
      one_card_to(diamonds_draw_pile)
    end

    one_card_to(foundation)

    11.times do |_|
      one_card_to(play_pile)
    end
  end

  private

  def one_card_to(pile)
    card = deal
    rank = determine_rank(card)
    suit = determine_suit(card)
    pile[card] = {rank: rank, suit: suit}
  end

  def determine_rank(file_name)
    case file_name[0]
    when 'a'
      1
    when 't'
      10
    when 'j'
      11
    when 'q'
      12
    when 'k'
      13
    else
      file_name[0].to_i
    end
  end

  def determine_suit(file_name)
    if file_name.include? 'spades'
      'spades'
    elsif file_name.include? 'hearts'
      'hearts'
    elsif file_name.include? 'clubs'
      'clubs'
    elsif file_name.include? 'diamonds'
      'diamonds'
    end
  end
end
