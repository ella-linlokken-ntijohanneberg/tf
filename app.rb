require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/flash'
require_relative './model.rb'
enable :sessions

include Model

#Checks if a user attempts to reach certain routes while not being logged in or being an admin
#
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

# Display Landing Page
#
get('/') do
  slim(:start)
end

# Display Start Page for Admin user
#
get('/admin') do
  slim(:"admin/start")
end

# Display Register Form
#
get('/register') do
  slim(:"user/register")
end

# Display Admin Login Form
#
get('/admin/login') do
  slim(:"admin/login")
end

# Attempts admin login and updates the session
# Redirects to '/admin' if successful login, '/admin/login' if unsuccessful login
#
# @param [String] :username, The username
# @param [String] :password, The password
# @param [Integer] :admin_pin, Admin pincode, if 0 then user is not an admin, if != 0 then user is admin
#
# @see Model#login_user
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

# Display Normal User Login Form
#
get('/login') do
  slim(:"user/login")
end

# Attempts login and updates the session
# Redirects to '/' if successful login, to '/login' if unsuccessful login
#
# @param [String] :username, The username
# @param [String] :password, The password
#
# @see Model#login_user
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

# Attempts register and login and updates the session
# Redirects to '/' if successful login, to '/register' if unsuccessful login
#
# @param [String] :username, The username
# @param [String] :password, The password
# @param [String] :password_confirm, The repeated password
#
# @see Model#register_user
# @see Model#check_user
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

#Clears all sessions and logs the user out
#
get('/clear_session') do
  session.clear
  flash[:message] = "You have been logged out!"
  slim(:start)
end

#Displays all existing users except the current admin user
#Stores all users in instance variable @result
#
# @see Model#select_users
get('/admin/users') do
  @result = select_users()
  slim(:"admin/user_index")
end

# Displays all projects of the current user
# Stores all user projects in instance variable @result
#
# @see Model#select_user_projects
get('/projects') do
  id = session[:id]
  @result = select_user_projects(id)
  slim(:"projects/index")
end

#Displays a form to create a new project
#Stores all craft types in instance variable @craft_type
#
# @see Model#select_all_crafts
get('/projects/new') do
  @craft_type = select_all_crafts()
  slim(:"projects/new")
end

#Creates a new project and redirects to '/projects'
#
# @param [String] :project_name, The new project's name
# @param [String] :craft_type, the craft type
#
# @see Model#new_project
post('/projects/new') do
  name = params[:project_name]
  craft_type = params[:craft_type]
  user_id = session[:id]
  new_project(name, craft_type, user_id)
  redirect('/projects')
end

#Displays one form to create a new craft type and another form to create a new craft attribute
#Stores all craft types in instance variable @craft_type
#
# @see Model#select_all_craft
get('/admin/craft_attribute/new') do
  @craft_type = select_all_crafts()
  slim(:"admin/new")
end

#Creates new craft type and redirects to '/admin/craft_attribute/new'
#
# @param [String] :craft_name, The new craft type name
#
# @see Model#new_craft_type
post('/admin/craft_type/new') do
  name = params[:craft_name]
  if new_craft_type(name) == nil
    flash[:message] = "This craft type already exists!"
    redirect('/admin/craft_attribute/new')
  end
  flash[:message] = "New craft type added!"
  redirect('/admin/craft_attribute/new')
end

# Creates new attribute and redirects to '/admin/craft_attribute/new'
#
# @param [String] :attribute_name, The new attribute name
# @param [String] :craft_type, The craft type in which the attribute will be applied to
#
# @see Model#new_attribute
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

# Deletes an existing project and redirects to '/projects'
#
# @param [Integer] :id, The ID of the project
#
# @see Model#delete_project
post('/projects/:id/delete') do
  id = params[:id].to_i
  delete_project(id)
  redirect('/projects')
end

# Deletes an existing user and its projects and redirects to '/admin/users'
#
# @param [Integer] :id, The ID of the user
#
# @see Model#delete_user
post('/admin/users/:id/delete') do
  id = params[:id].to_i
  delete_user(id)
  flash[:message] = "User has been deleted!"
  redirect('/admin/users')
end

# Adds 2 attributes and a description to an existing project and redirects to '/projects'
#
# @param [String] :description, The new description
# @param [String] :attribute_1, The first attribute's name
# @param [String] :attribute_2, The second attribute's name
#
# @see Model#add_project_info
post('/projects/:id/addinfo') do
  id = params[:id].to_i
  description = params[:description]
  attribute_1 = params[:attribute_1]
  attribute_2 = params[:attribute_2]
  add_project_info(id, attribute_1, attribute_2, description)
  redirect('/projects')
end

# Updates 2 attributes and the description of an existing project and redirects to '/projects'
#
# @param [String] :description, The new description
# @param [String] :attribute_1, The first attribute's name
# @param [String] :attribute_2, The second attribute's name
#
# @see Model#update_project_info
post('/projects/:id/update') do
  id = params[:id].to_i
  name = params[:project_name]
  description = params[:description]
  attribute_1 = params[:attribute_1]
  attribute_2 = params[:attribute_2]
  update_project_info(id, name, attribute_1, attribute_2, description)
  redirect('/projects')
end

# Updates a user's admin pincode to change admin status and redirects to '/admin/users'
#
# @param [Integer] :id, The id of the user
# @param [Integer] :admin_pin, The admin pincode of the user
#
# @see Model#give_admin_status
post('/admin/users/:id/update') do
  id = params[:id].to_i
  admin_pin = params[:admin_pin].to_i
  give_admin_status(id, admin_pin)
  flash[:message] = "User's admin pin has been changed!"
  redirect('/admin/users')
end

# Displays form to add or change project information
# Stores attributes that are related to the project's craft type in instance variable @attributes
# Stores the project in instance variable @result
#
# @param [Integer] :id, The project's id
#
# @see Model#select_project_craft_id
# @see Model#select_project_attributes_craft
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

# Displays information about one project
# Stores project information in instance variable @result
# Stores project's craft type in @craft_type
# Stores project*s attributes in @attributes
#
# @param [Integer] :id, The project's id
#
# @see Model#select_one_project
# @see Model#select_project_craft
# @see Model#select_project_attributes_project
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

# Checks if route is '/clear_session' and redirects to '/' after logout
after do
  if request.path_info == '/clear_session'
    redirect('/')
  end
end