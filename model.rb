require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'

def connect_to_db(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

def connect_to_db_no_hash(path)
    db = SQLite3::Database.new(path)
    return db
end

def login_user(username, password)
    db = connect_to_db('db/handmade.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    pwdigest = result["pwdigest"]
    if BCrypt::Password.new(pwdigest) == password
        return result
    else
        return nil
    end
end

def check_user(username)
    list_of_users = []
    db = connect_to_db('db/handmade.db')
    result = db.execute("SELECT * FROM users")
    result.each do |user|
        list_of_users << user['username']
    end
    return list_of_users.include?(username)
end

def register_user(username, password)
    password_digest = BCrypt::Password.create(password)
    db = connect_to_db('db/handmade.db')
    db.execute("INSERT INTO users (username, pwdigest) VALUES (?,?)", username, password_digest)
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    return result
end

def select_user_projects()
    db = connect_to_db('db/handmade.db')
    result = db.execute("SELECT * FROM projects WHERE user_id = ?", session[:id])
    return result
end

def select_one_project(id)
    db = connect_to_db('db/handmade.db')
    result = db.execute("SELECT * FROM projects WHERE project_id = ?", id).first
    return result
end

def select_all_crafts()
    db = connect_to_db('db/handmade.db')
    result = db.execute("SELECT * FROM Craft_type")
    return result
end

def new_project(name, craft_type, user_id)
    db = connect_to_db_no_hash('db/handmade.db')
    craft_type_id = db.execute("SELECT craft_type_id FROM Craft_type WHERE name = ?", craft_type).first
    db.execute("INSERT INTO projects (name, user_id, craft_type_id, has_attribute) VALUES (?,?,?,?)", name, user_id, craft_type_id, 0)
end

def delete_project(id)
    db = connect_to_db('db/handmade.db')
    db.execute("DELETE FROM projects WHERE project_id = ?", id)
    db.execute("DELETE FROM project_attribute_rel WHERE project_id = ?", id)
end

def add_project_attribute_rel(id, attribute, attribute_nbr)
    db = connect_to_db_no_hash('db/handmade.db')
    attribute_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute).first
    db.execute("INSERT INTO project_attribute_rel (project_id, attribute_id, attribute_nbr) VALUES (?,?,?)", id, attribute_id, attribute_nbr)
end

def add_project_info(id, attribute_1, attribute_2, description)
    db = connect_to_db_no_hash('db/handmade.db')
    add_project_attribute_rel(id, attribute_1, 1)
    add_project_attribute_rel(id, attribute_2, 2)
    db.execute("UPDATE projects SET has_attribute = ?, description = ? WHERE project_id = ?", 1, description, id)
end

def update_project_attribute_rel(id, attribute, attribute_nbr)
    db = connect_to_db_no_hash('db/handmade.db')
    attribute_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute).first
    db.execute("UPDATE project_attribute_rel SET attribute_id = ? WHERE project_id = ? AND attribute_nbr = ?", attribute_id, id, attribute_nbr)
end

def update_project_info(id, name, attribute_1, attribute_2, description)
    db = connect_to_db_no_hash('db/handmade.db')
    update_project_attribute_rel(id, attribute_1, 1)
    update_project_attribute_rel(id, attribute_2, 2)
    db.execute("UPDATE projects SET name = ?, description = ? WHERE project_id = ?", name, description, id)
end

def select_project_craft_id(id)
    db = connect_to_db('db/handmade.db')
    result = db.execute("SELECT craft_type_id FROM projects WHERE project_id = ?", id).first
    craft_type_id = result['craft_type_id']
    return craft_type_id
end

def select_project_attributes_craft(craft_type_id)
    db = connect_to_db('db/handmade.db')
    attributes = db.execute("SELECT * FROM Craft_attribute_rel 
                            INNER JOIN Attributes ON Craft_attribute_rel.attribute_id = Attributes.attribute_id
                            WHERE craft_id = ?", craft_type_id)
    return attributes
end

def select_project_craft(craft_type_id)
    db = connect_to_db('db/handmade.db')
    craft_type = db.execute("SELECT name FROM craft_type WHERE craft_type_id = ?", @result['craft_type_id']).first
    return craft_type
end

def select_project_attributes_project(id)
    db = connect_to_db('db/handmade.db')
    attributes = db.execute("SELECT * FROM Project_attribute_rel
                              INNER JOIN attributes ON Project_attribute_rel.attribute_id = attributes.attribute_id
                              WHERE project_id = ?", id)
    return attributes
end