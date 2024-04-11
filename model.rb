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
    if check_user(username) == true
        db = connect_to_db('db/handmade.db')
        result = db.execute("SELECT * FROM users WHERE username = ?", username).first
        pwdigest = result["pwdigest"]
        if BCrypt::Password.new(pwdigest) == password
            return result
        else
            return nil
        end
    else
        return false
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
    db.execute("INSERT INTO users (username, pwdigest, is_admin, has_project) VALUES (?,?,?,?)", username, password_digest, 0, 0)
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    return result
end

def select_users()
    db = connect_to_db('db/handmade.db')
    result = db.execute("SELECT * FROM users WHERE id != ?", session[:id])
    return result
end

def select_user_projects(id)
    db = connect_to_db('db/handmade.db')
    result = db.execute("SELECT * FROM projects WHERE user_id = ?", id)
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
    db.execute("UPDATE users SET has_project = ? WHERE id = ?", 1, user_id)
end

def new_craft_type(name)
    craft_types = []
    db = connect_to_db_no_hash('db/handmade.db')
    select_all_crafts().each do |craft_type|
        craft_types << craft_type['name']
    end
    if craft_types.include?(name.downcase)
        return nil
    else
        db.execute("INSERT INTO craft_type (name) VALUES (?)", name.downcase)
    end
end

def new_attribute(name, craft_type)
    attribute_exists = 0
    list_of_attributes = []
    db = connect_to_db('db/handmade.db')
    select_craft = db.execute("SELECT craft_type_id FROM craft_type WHERE name = ?", craft_type).first
    craft_type_id = select_craft['craft_type_id']
    attributes = db.execute("SELECT * FROM attributes")
    attributes.each do |attribute|
        list_of_attributes << attribute['name']
    end
    if list_of_attributes.include?(name.downcase)
        list_of_craft_ids = []
        attributes = db.execute("SELECT * FROM attributes
                    INNER JOIN craft_attribute_rel ON attributes.attribute_id = craft_attribute_rel.attribute_id
                    WHERE name = ?", name)
        attributes.each do |attribute|
            list_of_craft_ids << attribute['craft_id']
        end
        if list_of_craft_ids.include?(craft_type_id)
            attribute_exists = 1
        end
    end
    if attribute_exists == 0
        db = connect_to_db_no_hash('db/handmade.db')
        if list_of_attributes.include?(name.downcase) == false
            db.execute("INSERT INTO attributes (name) VALUES (?)", name.downcase)
        end
        attribute_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", name.downcase)
        db.execute("INSERT INTO craft_attribute_rel (craft_id, attribute_id) VALUES (?,?)", craft_type_id, attribute_id)
    else
        return nil
    end
end

def delete_project(id)
    db = connect_to_db('db/handmade.db')
    db.execute("DELETE FROM projects WHERE project_id = ?", id)
    db.execute("DELETE FROM project_attribute_rel WHERE project_id = ?", id)
end

def give_admin_status(id, admin_pin)
    db = connect_to_db_no_hash('db/handmade.db')
    db.execute("UPDATE users SET is_admin = ? WHERE id = ?", admin_pin, id)
end

def delete_user(id)
    db = connect_to_db('db/handmade.db')
    projects = db.execute("SELECT * FROM projects WHERE user_id = ?", id)
    projects.each do |project|
        db.execute("DELETE FROM project_attribute_rel WHERE project_id = ?", project['project_id'])
    end
    db.execute("DELETE FROM projects WHERE user_id = ?", id)
    db.execute("DELETE FROM users WHERE id = ?", id)
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