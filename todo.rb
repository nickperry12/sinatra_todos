# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
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

# GET    /lists                  --> view all lists
# GET    /lists/new              --> new list form
# POST   /lists                  --> create new lists
# GET    /lists/1....            --> view a single list
# GET    /list/(list number)     --> display the `todos` in the current list

# views all of the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form
get '/lists/new' do
  erb :new_list
end

# render the todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  @todos = session[:lists][@list_id][:todos]

  erb :list, layout: :layout
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

# edit an existing todo list
get '/lists/:id/edit' do
  id = params[:id].to_i
  @list = session[:lists][id]

  erb :edit_list, layout: :layout
end

# update an existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  error_message = list_name_error(list_name)
  id = params[:id].to_i
  @list = session[:lists][id]

  if error_message
    session[:error] = error_message
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{id}"
  end
end

# deletes the current list from todo lists
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = 'The list has been deleted.'
  redirect "/lists"
end

# add todo item to todo list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  todo = params[:todo].strip
  @list = session[:lists][@list_id]
  error_message = invalid_todo_name?(todo)
  
  if error_message
    session[:error] = error_message
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo, completed: false }
    session[:success] = "The todo was successfully added."
    redirect "/lists/#{@list_id}"
  end
end

# deletes the todo from the list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# updates the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @todo_id = params[:todo_id].to_i

  is_completed = params[:completed] == "true"
  @list[:todos][@todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# marks all todos as complete
post '/lists/:list_id/todos/:todo_id/complete%20all' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @todo_id = params[:todo_id].to_i

  @list[:todos].each { |todo| todo[:completed] = "true" }
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end

=begin
@list == { name: list_name, todos: [{name: todo_name, completed: true or false } <=(represented by todo_id), ] }

@list[@list_id][todo_id][:completed] = true
=end

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
  
  # checks to see if the provided todo name is valid
  def invalid_todo_name?(todo_name)
    if !(1..100).cover?(todo_name.size)
      "Todo must be between 1 and 100 characters."
    end
  end
end
