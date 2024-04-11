require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/flash'
require_relative './model.rb'
enable :sessions

before do
  if request.path_info != '/' && session[:id] == nil && request.path_info != '/login' && request.path_info != '/register' && request.path_info != '/admin/login'
    flash[:message] = "You need to sign in first!"
    redirect('/login')
  end
  if session[:admin] == 0 && request.path_info == '/admin' || session[:admin] == 0 && request.path_info == '/admin/users' || session[:admin] == 0 && request.path_info == '/admin/craft_attribute/new'
    flash[:message] = "You don't have authorization to view this page!"
    redirect('/')
  end
end

get('/') do
  slim(:start)
end

get('/admin') do
  slim(:"admin/start")
end

get('/register') do
  slim(:"user/register")
end

get('/admin/login') do
  slim(:"admin/login")
end

post('/admin/login') do
  username = params[:username]
  password = params[:password]
  admin_pin = params[:admin_pin].to_i
  result = login_user(username, password)
  if result == nil
    flash[:message] = "Wrong password!"
    redirect('/admin/login')
  elsif result == false
    flash[:message] = "Wrong username!"
    redirect('/admin/login')
  else
    if admin_pin == result["is_admin"] && admin_pin != 0
      session[:id] = result["id"]
      session[:name] = result["username"]
      session[:admin] = result["is_admin"]
      redirect('/admin')
    else
      flash[:message] = "That is not an Admin Pincode!"
      redirect('/admin/login')
    end
  end
end

get('/login') do
  slim(:"user/login")
end

post('/login') do
  username = params[:username]
  password = params[:password]
  result = login_user(username, password)
  if result == nil
    flash[:message] = "Wrong password!"
    redirect('/login')
  elsif result == false
    flash[:message] = "Wrong username!"
    redirect('/login')
  else
    session[:id] = result["id"]
    session[:name] = result["username"]
    session[:admin] = result["is_admin"]
    if session[:admin] != 0
      flash[:message] = "You can log in as admin with pincode #{session[:admin]}!"
    end
    redirect('/')
  end
end

post('/register') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  if password == password_confirm && check_user(username) == false && password.length > 0 && username.length > 0
    result = register_user(username, password)
    session[:id] = result["id"]
    session[:name] = result["username"]
    session[:admin] = result["is_admin"]
    redirect('/')
  elsif check_user(username) == true
    flash[:message] = "Username is already taken!"
    redirect('/register')
  elsif password.length < 1
    flash[:message] = "Password must contain at least 1 character"
    redirect('/register')
  elsif username.length < 1
    flash[:message] = "Username must contain at least 1 character"
    redirect('/register')
  else
    flash[:message] = "No matching passwords!"
    redirect('/register')
  end
end

get('/clear_session') do
  session.clear
  flash[:message] = "You have been logged out!"
  slim(:start)
 end
 
get('/admin/users') do
  @result = select_users()
  slim(:"admin/user_index")
end

get('/projects') do
  id = session[:id]
  @result = select_user_projects(id)
  slim(:"projects/index")
end

get('/projects/new') do
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

get('/admin/craft_attribute/new') do
  @craft_type = select_all_crafts()
  slim(:"admin/new")
end

post('/admin/craft_type/new') do
  name = params[:craft_name]
  if new_craft_type(name) == nil
    flash[:message] = "This craft type already exists!"
    redirect('/admin/craft_attribute/new')
  end
  flash[:message] = "New craft type added!"
  redirect('/admin/craft_attribute/new')
end

post('/admin/attribute/new') do
  name = params[:attribute_name]
  craft_type = params[:craft_type]
  if new_attribute(name, craft_type) == nil
    flash[:message] = "This attribute already exists!"
    redirect('/admin/craft_attribute/new')
  end
  flash[:message] = "New attribute added!"
  redirect('/admin/craft_attribute/new')
end

post('/projects/:id/delete') do
  id = params[:id].to_i
  delete_project(id)
  redirect('/projects')
end

post('/admin/users/:id/delete') do
  id = params[:id].to_i
  delete_user(id)
  flash[:message] = "User has been deleted!"
  redirect('/admin/users')
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

post('/admin/users/:id/update') do
  id = params[:id].to_i
  admin_pin = params[:admin_pin]
  give_admin_status(id, admin_pin)
  flash[:message] = "User's admin pin has been changed!"
  redirect('/admin/users')
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
    flash[:message] = "Not your project, who do you think you are?!"
    redirect('/projects')
  end
  slim(:"projects/show")
end

after do
  if request.path_info == '/clear_session'
    redirect('/')
  end
end