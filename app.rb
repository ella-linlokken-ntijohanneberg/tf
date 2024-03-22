require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
enable :sessions

get('/') do
  slim(:start)
end

get('/projects') do
  db = SQLite3::Database.new('db/handmade.db')
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM projects")
  p @result
  slim(:"projects/index")
end

get('/projects/new') do
  db = SQLite3::Database.new('db/handmade.db')
  db.results_as_hash = true
  @craft_type = db.execute("SELECT * FROM Craft_type")
  p @craft_type
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
  redirect('/projects')
end

post('/projects/:id/addinfo') do
  id = params[:id].to_i
  name = params[:project_name]
  description = params[:description]
  attribute_1 = params[:attribute_1]
  db = SQLite3::Database.new('db/handmade.db')
  attribute_1_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute_1).first
  db.execute("INSERT INTO project_attribute_rel (project_id, attribute_id) VALUES (?,?)", id, attribute_1_id)
  db.execute("UPDATE projects SET has_attribute = ?, description = ? WHERE project_id = ?", 1, description, id)
  redirect('/projects')
end

post('/projects/:id/update') do
  id = params[:id].to_i
  name = params[:project_name]
  description = params[:description]
  attribute_1 = params[:attribute_1]
  db = SQLite3::Database.new('db/handmade.db')
  attribute_1_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute_1).first
  db.execute("UPDATE projects SET name = ?, description = ? WHERE project_id = ?", name, description, id)
  db.execute("UPDATE project_attribute_rel SET attribute_id = ? WHERE project_id = ?", attribute_1_id, id)
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
  slim(:"projects/show")
end