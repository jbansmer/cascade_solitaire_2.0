require "sinatra"
require "sinatra/content_for"
require "tilt/erubi"

require_relative "./dealer.rb"
require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

before do
  @game_layout = DatabasePersistence.new(logger)
end

after do
  @game_layout.disconnect
end

helpers do
  def sort_playable_cards(current_pile, &block)
    play_piles = @game_layout.all_current_pile_cards
    playable_pile = play_piles.select { |pile| pile[:pile_id].to_i == current_pile }

    playable_pile.each(&block)
  end

  def any_cards_in_next_play_pile?(current_pile)
    pile_1, pile_2 = @game_layout.cards_in_each_play_pile

    current_pile == 1 ? !pile_2.zero? : !pile_1.zero?
  end

  def any_cards_in_draw_pile?(pile_suit)
    spades, hearts, clubs, diamonds = @game_layout.cards_in_each_draw_pile
    
    case pile_suit
    when "spades" then !spades.zero?
    when "hearts" then !hearts.zero?
    when "clubs" then !clubs.zero?
    when "diamonds" then !diamonds.zero?
    end
  end

  def view_the_leaderboard(&block)
    names_and_scores = @game_layout.all_high_scores

    names_and_scores.each(&block)
  end

  def any_cards_in_current_play_pile?(current_pile)
    pile_1, pile_2 = @game_layout.cards_in_each_play_pile

    current_pile == 1 ? !pile_1.zero? : !pile_2.zero?
  end
end

def current_high_score(name)
  @game_layout.current_high_score(name)
end

def update_high_score(name)
  current_score = @game_layout.current_score.to_i

  if current_score > @game_layout.current_high_score(name).to_i
    @game_layout.new_high_score(current_score, name)
  end
end

get "/" do
  @login = false

  erb :home, layout: :home
end

get "/login" do
  @login = true
  @name = session[:name]

  erb :login, layout: :home
end

get "/practice" do
  session.delete(:name)
  @game_layout.deal_new_game
  redirect "/play/1"
end

get "/play" do
  session[:high_score] = current_high_score(session[:name])
  @game_layout.deal_new_game
  redirect "/play/1"
end

post "/play" do
  session[:name] = params[:name]
  session[:high_score] = current_high_score(session[:name])
  @game_layout.deal_new_game
  redirect "/play/1"
end

get "/play/:current_pile" do
  @name = session[:name]
  @high_score = session[:high_score]
  @score = @game_layout.current_score
  @current_pile = params[:current_pile].to_i
  @foundation = @game_layout.current_foundation

  if any_cards_in_current_play_pile?(@current_pile)
    erb :play, layout: :layout
  else
    next_pile = @current_pile == 1 ? 2 : 1
    redirect "/play/#{next_pile}"
  end
end

post "/switch_pile" do
  next_pile = params[:switch_piles]
  redirect "/play/#{next_pile}"
end

post "/:current_pile/:rank/:suit" do
  @current_pile = params[:current_pile]
  rank = params[:rank]
  suit = params[:suit]
  name = session[:name]

  if @game_layout.card_playable_to_foundation?(rank, suit)
    @game_layout.play_card_to_foundation(rank, suit)
  else
    session[:error] = "The rank or suit must match the foundation!"
  end

  update_high_score(name) if name

  redirect "/play/#{@current_pile}"
end
