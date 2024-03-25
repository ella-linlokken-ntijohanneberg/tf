require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
enable :sessions

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
  db = SQLite3::Database.new('db/handmade.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM users WHERE username = ?", username).first
  pwdigest = result["pwdigest"]
  id = result["id"]

  if BCrypt::Password.new(pwdigest) == password
    session[:id] = id
    redirect('/')
  else
    "Wrong password"
  end
end

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  if password == password_confirm
    password_digest = BCrypt::Password.create(password)
    db = SQLite3::Database.new('db/handmade.db')
    db.execute("INSERT INTO users (username, pwdigest) VALUES (?,?)", username, password_digest)
    id = db.execute("SELECT id FROM users WHERE username = ?", username).first
    session[:id] = id
    redirect('/')
  else
    "No matching passwords"
  end
end

get('/clear_session') do
  session.clear
  slim(:login)
 end
 

get('/projects') do
  db = SQLite3::Database.new('db/handmade.db')
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM projects WHERE user_id = ?", session[:id])
  slim(:"projects/index")
end

get('/projects/new') do
  db = SQLite3::Database.new('db/handmade.db')
  db.results_as_hash = true
  @craft_type = db.execute("SELECT * FROM Craft_type")
  slim(:"projects/new")
end

post('/projects/new') do
  name = params[:project_name]
  craft_type = params[:craft_type]
  user_id = params[:user_id].to_i
  db = SQLite3::Database.new('db/handmade.db')
  craft_type_id = db.execute("SELECT craft_type_id FROM Craft_type WHERE name = ?", craft_type).first
  db.execute("INSERT INTO projects (name, user_id, craft_type_id, has_attribute) VALUES (?,?,?,?)", name, user_id, craft_type_id, 0)
  redirect('/projects')
end

post('/projects/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new('db/handmade.db')
  db.execute("DELETE FROM projects WHERE project_id = ?", id)
  db.execute("DELETE FROM project_attribute_rel WHERE project_id = ?", id)
  redirect('/projects')
end

post('/projects/:id/addinfo') do
  id = params[:id].to_i
  name = params[:project_name]
  description = params[:description]
  attribute_1 = params[:attribute_1]
  attribute_2 = params[:attribute_2]
  db = SQLite3::Database.new('db/handmade.db')
  attribute_1_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute_1).first
  db.execute("INSERT INTO project_attribute_rel (project_id, attribute_id, attribute_nbr) VALUES (?,?,?)", id, attribute_1_id, 1)
  attribute_2_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute_2).first
  db.execute("INSERT INTO project_attribute_rel (project_id, attribute_id, attribute_nbr) VALUES (?,?,?)", id, attribute_2_id, 2)
  db.execute("UPDATE projects SET has_attribute = ?, description = ? WHERE project_id = ?", 1, description, id)
  redirect('/projects')
end

post('/projects/:id/update') do
  id = params[:id].to_i
  name = params[:project_name]
  description = params[:description]
  attribute_1 = params[:attribute_1]
  attribute_2 = params[:attribute_2]
  db = SQLite3::Database.new('db/handmade.db')
  attribute_1_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute_1).first
  attribute_2_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute_2).first
  db.execute("UPDATE projects SET name = ?, description = ? WHERE project_id = ?", name, description, id)
  db.execute("UPDATE project_attribute_rel SET attribute_id = ? WHERE project_id = ? AND attribute_nbr = ?", attribute_1_id, id, 1)
  db.execute("UPDATE project_attribute_rel SET attribute_id = ? WHERE project_id = ? AND attribute_nbr = ?", attribute_2_id, id, 2)
  redirect('/projects')
end

get('/projects/:id/edit') do
  id = params[:id].to_i
  db = SQLite3::Database.new('db/handmade.db')
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM projects WHERE project_id = ?", id).first
  craft_type_id = @result['craft_type_id']
  @attributes = db.execute("SELECT * FROM Craft_attribute_rel 
                            INNER JOIN Attributes ON Craft_attribute_rel.attribute_id = Attributes.attribute_id
                            WHERE craft_id = ?", craft_type_id)
  p @attributes
  if @result['has_attribute'].to_i == 0
    slim(:"/projects/addinfo")
  else
    slim(:"/projects/edit")
  end
end

get('/projects/:id') do
  id = params[:id].to_i
  db = SQLite3::Database.new('db/handmade.db')
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM projects WHERE project_id = ?", id).first
  @craft_type = db.execute("SELECT name FROM craft_type WHERE craft_type_id = ?", @result['craft_type_id']).first
  @attributes = db.execute("SELECT * FROM Project_attribute_rel
                            INNER JOIN attributes ON Project_attribute_rel.attribute_id = attributes.attribute_id
                            WHERE project_id = ?", @result['project_id'])
  p @attributes
  slim(:"projects/show")
end