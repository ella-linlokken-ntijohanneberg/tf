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
  @craft_type = db.execute("SELECT name FROM Craft_type")
  p @craft_type
  slim(:"projects/new")
end

post('/projects/new') do
  name = params[:project_name]
  craft_id = params[:craft_id].to_i
  user_id = params[:user_id].to_i
  db = SQLite3::Database.new('db/handmade.db')
  db.execute("INSERT INTO projects (name, craft_type_id, user_id) VALUES (?,?,?)", name, craft_id, user_id)
  redirect('/projects')
end

post('/projects/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new('db/handmade.db')
  db.execute("DELETE FROM projects WHERE project_id = ?", id)
  redirect('/projects')
end

get('/projects/:id') do
  id = params[:id].to_i
  db = SQLite3::Database.new('db/handmade.db')
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM projects WHERE project_id = ?", id).first
  p @result
  slim(:"projects/show")
end