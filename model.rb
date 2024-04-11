require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
module Model

    # Connects to database
    # Returns data as hashes
    def connect_to_db(path)
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        return db
    end

    # Connects to database
    # Returns data as arrays
    def connect_to_db_no_hash(path)
        db = SQLite3::Database.new(path)
        return db
    end

    # Attempts to sign in user
    #
    # username [String] the name of the user
    # password [String] the password of the user
    #
    # Returns user information from database if password matches and if username exists as hash
    # Returns nil if input password does not match database password
    # Returns false if username does not exist
    #
    # @see Model#check_user
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

    # Checks if input username exists in database
    #
    # username [String] name of the user
    #
    # Returns Boolean depending on if the username exists
    def check_user(username)
        list_of_users = []
        db = connect_to_db('db/handmade.db')
        result = db.execute("SELECT * FROM users")
        result.each do |user|
            list_of_users << user['username']
        end
        return list_of_users.include?(username)
    end
    
    # Attempt to register user
    #
    # username [String] name of the user
    # password [String] password of the user
    #
    # Returns the new user information from database as hash
    def register_user(username, password)
        password_digest = BCrypt::Password.create(password)
        db = connect_to_db('db/handmade.db')
        db.execute("INSERT INTO users (username, pwdigest, is_admin, has_project) VALUES (?,?,?,?)", username, password_digest, 0, 0)
        result = db.execute("SELECT * FROM users WHERE username = ?", username).first
        return result
    end

    #Selects all users except the current user
    #Returns an array with user hashes
    def select_users()
        db = connect_to_db('db/handmade.db')
        result = db.execute("SELECT * FROM users WHERE id != ?", session[:id])
        return result
    end

    # Selects a user's projects from database
    #
    # id [Integer] the user's id
    #
    # Returns an array with project hashes
    def select_user_projects(id)
        db = connect_to_db('db/handmade.db')
        result = db.execute("SELECT * FROM projects WHERE user_id = ?", id)
        return result
    end

    # Selects one project from database
    #
    # id [Integer] the project's id
    #
    # Returns a project hash
    def select_one_project(id)
        db = connect_to_db('db/handmade.db')
        result = db.execute("SELECT * FROM projects WHERE project_id = ?", id).first
        return result
    end

    # Selects everything from craft_type table in database
    # Returns an array with craft type hashes
    def select_all_crafts()
        db = connect_to_db('db/handmade.db')
        result = db.execute("SELECT * FROM Craft_type")
        return result
    end

    # Creates a new project by inserting into database
    #
    # name [String] name of the new project
    # craft_type [String] name of the project's craft type
    # user_id [Integer] the user's id
    def new_project(name, craft_type, user_id)
        db = connect_to_db_no_hash('db/handmade.db')
        craft_type_id = db.execute("SELECT craft_type_id FROM Craft_type WHERE name = ?", craft_type).first
        db.execute("INSERT INTO projects (name, user_id, craft_type_id, has_attribute) VALUES (?,?,?,?)", name, user_id, craft_type_id, 0)
        db.execute("UPDATE users SET has_project = ? WHERE id = ?", 1, user_id)
    end

    # Creates a new craft type
    #
    # name [String] the name of the new craft type
    #
    # Returns nil if name exists and inserts name into database if name does not exist
    #
    # @see Model#select_all_crafts
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

    # Creates a new attribute if attribute does not exist or if attribute is not applied to the chosen craft type
    #
    # name [String] the name of the new attribute
    # craft_type [String] the name of the chosen craft type
    #
    # Returns nil if attribute already exists and is related to the craft type's id,
    # Inserts name into attributes table
    # Inserts name's id and craft_type's id into craft_attribute_rel
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
        if list_of_attributes.include?(name.downcase) #checks if name exists in attributes-table
            list_of_craft_ids = []
            attributes = db.execute("SELECT * FROM attributes
                        INNER JOIN craft_attribute_rel ON attributes.attribute_id = craft_attribute_rel.attribute_id
                        WHERE name = ?", name)
            attributes.each do |attribute|
                list_of_craft_ids << attribute['craft_id']
            end
            if list_of_craft_ids.include?(craft_type_id) #checks if the craft type id is related to the attribute id
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

    # Deletes a project from projects table
    # Deletes attributes related to the project from project_attribute_rel table
    #
    # id [Integer] the project's id
    def delete_project(id)
        db = connect_to_db('db/handmade.db')
        db.execute("DELETE FROM projects WHERE project_id = ?", id)
        db.execute("DELETE FROM project_attribute_rel WHERE project_id = ?", id)
    end

    # Updates a user's admin pin in users table
    #
    # id [Integer] the user's id
    # admin_pin [Integer] the user's admin pincode
    def give_admin_status(id, admin_pin)
        db = connect_to_db_no_hash('db/handmade.db')
        db.execute("UPDATE users SET is_admin = ? WHERE id = ?", admin_pin, id)
    end

    # Deletes a user, its projects and the attributes related to the users projects
    #
    # id [Integer] the user's id
    def delete_user(id)
        db = connect_to_db('db/handmade.db')
        projects = db.execute("SELECT * FROM projects WHERE user_id = ?", id)
        projects.each do |project|
            db.execute("DELETE FROM project_attribute_rel WHERE project_id = ?", project['project_id'])
        end
        db.execute("DELETE FROM projects WHERE user_id = ?", id)
        db.execute("DELETE FROM users WHERE id = ?", id)
    end

    # Adds project id and attribute id to project_attribute_rel table
    #
    # id [Integer] the project's id
    # attribute [String] the name of the attribute, used to get attribute_id from attributes table
    # attribute_nbr [Integer] the number of the attribute to differentiate several attributes of the same project
    def add_project_attribute_rel(id, attribute, attribute_nbr)
        db = connect_to_db_no_hash('db/handmade.db')
        attribute_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute).first
        db.execute("INSERT INTO project_attribute_rel (project_id, attribute_id, attribute_nbr) VALUES (?,?,?)", id, attribute_id, attribute_nbr)
    end

    # Adds new information to a project
    #
    # id [Integer] the project's id
    # attribute_1 [String] name of the first attribute
    # attribute_2 [String] name of the second attribute
    # description [String] project's description
    #
    # @see Model#add_project_attribute_rel
    def add_project_info(id, attribute_1, attribute_2, description)
        db = connect_to_db_no_hash('db/handmade.db')
        add_project_attribute_rel(id, attribute_1, 1)
        add_project_attribute_rel(id, attribute_2, 2)
        db.execute("UPDATE projects SET has_attribute = ?, description = ? WHERE project_id = ?", 1, description, id)
    end

    # Updates a project's attribute id:s in relation table
    #
    # id [Integer] the project's id
    # attribute [String] the name of the attribute
    # attribute_nbr [Integer] the number of the attribute
    def update_project_attribute_rel(id, attribute, attribute_nbr)
        db = connect_to_db_no_hash('db/handmade.db')
        attribute_id = db.execute("SELECT attribute_id FROM attributes WHERE name = ?", attribute).first
        db.execute("UPDATE project_attribute_rel SET attribute_id = ? WHERE project_id = ? AND attribute_nbr = ?", attribute_id, id, attribute_nbr)
    end

    # Updates existing information about a project
    #
    # id [Integer] project's id
    # name [String] name of the project
    # attribute_1 [String] name of the first attribute
    # attribute_2 [String] name of the second attribute
    # description [String] project's description
    #
    # @see Model#update_project_attribute_rel
    def update_project_info(id, name, attribute_1, attribute_2, description)
        db = connect_to_db_no_hash('db/handmade.db')
        update_project_attribute_rel(id, attribute_1, 1)
        update_project_attribute_rel(id, attribute_2, 2)
        db.execute("UPDATE projects SET name = ?, description = ? WHERE project_id = ?", name, description, id)
    end

    # Selects the craft type of a specific project
    #
    # id [Integer] the project's id
    #
    # Returns the craft type id as an integer
    def select_project_craft_id(id)
        db = connect_to_db('db/handmade.db')
        result = db.execute("SELECT craft_type_id FROM projects WHERE project_id = ?", id).first
        craft_type_id = result['craft_type_id']
        return craft_type_id
    end

    # Selects all attributes related to a specific craft type
    #
    # craft_type_id [Integer] the id of the craft type
    #
    # Returns an array with attribute hashes
    def select_project_attributes_craft(craft_type_id)
        db = connect_to_db('db/handmade.db')
        attributes = db.execute("SELECT * FROM Craft_attribute_rel 
                                INNER JOIN Attributes ON Craft_attribute_rel.attribute_id = Attributes.attribute_id
                                WHERE craft_id = ?", craft_type_id)
        return attributes
    end

    # Selects the craft type of a project
    #
    # craft_type_id [Integer] the id of the craft_type
    #
    # Returns the craft type name as a hash
    def select_project_craft(craft_type_id)
        db = connect_to_db('db/handmade.db')
        craft_type = db.execute("SELECT name FROM craft_type WHERE craft_type_id = ?", @result['craft_type_id']).first
        return craft_type
    end

    # Selects all attributes related to a project
    #
    # id [Integer] the project's id
    #
    # Returns attributes in an array with hashes
    def select_project_attributes_project(id)
        db = connect_to_db('db/handmade.db')
        attributes = db.execute("SELECT * FROM Project_attribute_rel
                                INNER JOIN attributes ON Project_attribute_rel.attribute_id = attributes.attribute_id
                                WHERE project_id = ?", id)
        return attributes
    end
end