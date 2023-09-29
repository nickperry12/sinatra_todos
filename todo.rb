# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET    /lists          --> view all lists
# GET    /lists/new      --> new list form
# POST   /lists          --> create new lists
# GET    /lists/1....    --> View a single list

# views all of the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# creates a new list, redirects back to lists page
post '/lists' do
  list_name = params[:list_name].strip
  error_message = list_name_error(list_name)

  if error_message
    session[:error] = error_message
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

helpers do
  # validates list name length
  def invalid_list_name?(list_name)
    !(1..100).cover?(list_name.size)
  end

  # validates the list name being unique
  def list_name_exists?(list_name)
    session[:lists].any? { |list| list[:name] == list_name }
  end

  # either returns nil if the name is valid, or the appropriate error message
  def list_name_error(name)
    if invalid_list_name?(name)
      'The list name must be between 1 and 100 characters.'
    elsif list_name_exists?(name)
      'The list name you have chosen already exists. Please enter a new name.'
    end
  end
end
