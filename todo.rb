# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true
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
  
  # checks to see if the provided todo name is valid
  def invalid_todo_name?(todo_name)
    if !(1..100).cover?(todo_name.size)
      "Todo must be between 1 and 100 characters."
    end
  end

  # checks to see if all todos are completed
  def all_todos_completed?(list)
    list.all? { |todo| todo[:completed] == true } && list.size > 0
  end

  # assigns a value to the class attribute in our view templates
  def list_class(list)
    "complete" if all_todos_completed?(list)
  end

  # displays the number of completed todos out of the total todos
  def display_num_completed_todos(list)
    num_completed = list.select { |todo| todo[:completed] == true }.size
    total_todos = list.size

    "#{num_completed}/#{total_todos}"
  end

  # sorts the list of todos -- completed todos appear first in list
  def sort_todo_list_by_completed!(list)
    list[:todos].sort_by! do |todo|
      todo[:completed] == true ? 0 : 1
    end

    list
  end

  def load_list(list_id)
    list = session[:lists][list_id] if list_id && session[:lists][list_id]

    return list if list

    session[:error] = "The specified list was not found."
    redirect "/lists"
  end

  def generate_todo_id(todos)
    max = todos.map { |todo| todo[:id] }.max || 0
    max + 1
  end
end

before do
  session[:lists] ||= []
end

# redirects to lists page
get '/' do
  redirect '/lists'
end

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
  @list = load_list(@list_id)
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
  @list = @list = load_list(id)

  erb :edit_list, layout: :layout
end

# update an existing todo list
post '/lists/:id' do
  list_name = params[:list_name].strip
  error_message = list_name_error(list_name)
  id = params[:id].to_i
  @list = load_list(id)

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
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = 'The list has been deleted.'
    redirect "/lists"
  end
end

# add todo item to todo list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  todo = params[:todo].strip
  @list = load_list(@list_id)
  error_message = invalid_todo_name?(todo)
  
  if error_message
    session[:error] = error_message
    erb :list, layout: :layout
  else
    id = generate_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: todo, completed: false }
    session[:success] = "The todo was successfully added."
    redirect "/lists/#{@list_id}"
  end
end

# deletes the todo from the list
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(@todo_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# updates the status of a todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todo_id = params[:todo_id].to_i

  is_completed = params[:completed] == "true"
  @list[:todos][@todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# marks all todos as complete
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end

=begin
{ name: list_name, todos: [{ name: todo, completed: false }] }

we want to grab the list, and sort the `todos`
name[:todos] => iterate through this
  sort the list of todos by whether or not they're completed
=end