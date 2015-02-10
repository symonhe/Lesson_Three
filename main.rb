require 'rubygems'
require 'sinatra'

#set :sessions, true

use Rack::Session::Cookie,  :key => 'rack.session',
                                       :path => '/',
                                       :secret => 'blastoff'


BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17

helpers do

  def calculate_total(cards) #cards is [['H', '9'], ['D', 3], ...]
    arr = cards.map{ |element| element[1]}

    total = 0
    arr.each do |a|
      if a == "A"
        total += 11
      else
        total += a.to_i == 0 ? 10 : a.to_i
      end
    end

    #adjustment for Aces to only add if <21
    arr.select{|element| element == "A"}.count.times do
      break if total <= 21
      total -=10
    end

    total
  end

  def card_image(card) #['J', '3'] format

    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end

    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
        when 'J' then 'Jack'
        when 'Q' then 'Queen'
        when 'K' then 'King'
        when 'A' then 'Ace'
      end
    end

    "<img class = 'cards' src='/images/cards/#{suit}_#{value}.jpg'>"
  end

  def loser!(msg)
     @play_again = true
     @error = "<strong>#{session[:player_name]} loses!</strong> #{msg}"
     @show_hit_stay_buttons = false
     session[:player_chip_count] -= session[:player_bet]
     session[:player_bet] = 0
  end

  def winner!(msg)
    @play_again = true
    @success = "<strong>#{session[:player_name]} wins!</strong> #{msg}"
    @show_hit_stay_buttons = false
    session[:player_chip_count] += session[:player_bet]
    session[:player_bet] = 0
  end

  def tie!(msg)
    @play_again = true
    @success = "<strong>It's a tie!</strong> #{msg}"
    @show_hit_stay_buttons = false
  end
end

before do
  @show_hit_stay_buttons = true
  erb :new_player
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  erb :new_player
end

post '/new_player' do
  if params[:player_name].empty?
      @error = "Name is required"
      halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]

  session[:player_chip_count] = 0 #initialize to zero
  redirect '/starting_chips'
end

get '/starting_chips' do
  erb :starting_chips
end

post '/starting_chips' do

  if params[:player_chip_count].empty? || params[:player_chip_count].to_i < 500
      @error = "Must start with at least 500"
      halt erb(:starting_chips)
  end

  session[:player_chip_count] = params[:player_chip_count].to_i
  redirect '/take_bet'
end

get '/take_bet' do
  erb :take_bet
end

post '/take_bet' do
  if params[:player_bet].empty? || params[:player_bet].to_i < 0 || params[:player_bet].to_i > session[:player_chip_count].to_i
      @error = "Must enter valid bet between 0 and your chip count of #{session[:player_chip_count]}"
      halt erb(:take_bet)
  end

  session[:player_bet] = params[:player_bet].to_i
  redirect '/game'

end


get '/game' do
  session[:turn] = 'player'

  #set up deck
  suits = ['S', 'H', 'C', 'D']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!

  session[:dealer_cards] = []
  session[:player_cards] = []

  #deal initial cards
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  erb :game
end

post '/game/player/hit' do
    session[:player_cards] << session[:deck].pop

    player_total = calculate_total(session[:player_cards])
    if player_total > BLACKJACK_AMOUNT
      loser!("Looks like #{session[:player_name]} busted.")
    end

    erb :game
end

post '/game/player/stay' do
    @show_hit_stay_buttons = false
    player_total = calculate_total(session[:player_cards])
    dealer_total = calculate_total(session[:dealer_cards])

    if player_total == BLACKJACK_AMOUNT && session[:player_cards].count == 2
      redirect '/game/compare'
    else
      redirect '/game/dealer'
    end

end

get '/game/dealer' do
  session[:turn] = 'dealer'
   @show_hit_stay_buttons = false
  #dealer decisions
  dealer_total = calculate_total(session[:dealer_cards])

  if dealer_total == BLACKJACK_AMOUNT && session[:dealer_cards].count == 2 && !(player_total == BLACKJACK_AMOUNT && session[:player_cards].count == 2)
    loser!("Dealer has hit blackjack.")
  elsif dealer_total >BLACKJACK_AMOUNT
    winner!("Looks like the dealer has busted.")
  elsif dealer_total >= DEALER_MIN_HIT
    redirect '/game/compare'
  else
    #dealer hits
    @show_dealer_hit_button = true
  end

  erb :game
end

post '/game/dealer/hit' do
  session[:dealer_cards]<< session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  session[:turn] = 'dealer'
  dealer_total = calculate_total(session[:dealer_cards])
  player_total = calculate_total(session[:player_cards])

  if dealer_total > player_total
    loser!("Dealer's #{dealer_total} is greater than #{session[:player_name]}'s #{player_total}.")
  elsif dealer_total <player_total
    if player_total == 21 and session[:player_cards].count == 2
      winner!("Blackjack!")
    else
      winner!("Dealer's #{dealer_total} is less than #{session[:player_name]}'s #{player_total}.")
    end
  else
    tie!("Dealer's #{dealer_total} is equal to #{session[:player_name]}'s #{player_total}.")
  end

  erb :game
end

get '/game_over' do
  erb :game_over
end












