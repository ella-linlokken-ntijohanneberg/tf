require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/flash'
require_relative './model.rb'
enable :sessions

before do
  if request.path_info != '/' && session[:id] == nil && request.path_info != '/login' && request.path_info != '/register'
    flash[:not_logged_in] = "You need to sign in first!"
    redirect('/login')
  end
end

get('/') do
  slim(:start)
end

get('/register') do
  slim(:register)
end

get('/login') do
  slim(:login)
end

post('/login') do
  username = params[:username]
  password = params[:password]
  result = login_user(username, password)
  if result == nil
    flash[:wrong_pwd] = "Wrong password!"
    redirect('/login')
  else
    id = result["id"]
    name = result["username"]
    session[:id] = id
    session[:name] = name
    redirect('/')
  end
end

post('/register') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  if password == password_confirm && check_user(username) == false
    result = register_user(username, password)
    session[:id] = result["id"]
    session[:name] = result["username"]
    redirect('/')
  elsif check_user(username) == true
    flash[:exists] = "Username is already taken!"
    redirect('/register')
  else
    flash[:mismatch] = "No matching passwords!"
    redirect('/register')
  end
end

get('/clear_session') do
  session.clear
  flash[:logout] = "You have been logged out!"
  slim(:start)
 end
 

get('/projects') do
  @result = select_user_projects()
  slim(:"projects/index")
end

get('/projects/new') do
  db = connect_to_db('db/handmade.db')
  @craft_type = select_all_crafts()
  slim(:"projects/new")
end

post('/projects/new') do
  name = params[:project_name]
  craft_type = params[:craft_type]
  user_id = session[:id]
  new_project(name, craft_type, user_id)
  redirect('/projects')
end

post('/projects/:id/delete') do
  id = params[:id].to_i
  delete_project(id)
  redirect('/projects')
end

post('/projects/:id/addinfo') do
  id = params[:id].to_i
  description = params[:description]
  attribute_1 = params[:attribute_1]
  attribute_2 = params[:attribute_2]
  add_project_info(id, attribute_1, attribute_2, description)
  redirect('/projects')
end

post('/projects/:id/update') do
  id = params[:id].to_i
  name = params[:project_name]
  description = params[:description]
  attribute_1 = params[:attribute_1]
  attribute_2 = params[:attribute_2]
  update_project_info(id, name, attribute_1, attribute_2, description)
  redirect('/projects')
end

get('/projects/:id/edit') do
  id = params[:id].to_i
  craft_type_id = select_project_craft_id(id)
  @attributes = select_project_attributes_craft(craft_type_id)
  @result = select_one_project(id)
  if @result['has_attribute'].to_i == 0
    slim(:"/projects/addinfo")
  else
    slim(:"/projects/edit")
  end
end

get('/projects/:id') do
  id = params[:id].to_i
  @result = select_one_project(id)
  craft_type_id = @result['craft_type_id']
  if @result['user_id'] == session[:id]
    @craft_type = select_project_craft(craft_type_id)
    @attributes = select_project_attributes_project(id)
  else
    flash[:not_user_project] = "Not your project, who do you think you are?!"
    redirect('/projects')
  end
  slim(:"projects/show")
end

after do
  if request.path_info == '/clear_session'
    redirect('/')
  end
end