#!/usr/bin/env python3
import psycopg2
from psycopg2.extras import DictCursor

#####################################################
##  Database Connection
#####################################################

'''
Connect to the database using the connection string
'''
def openConnection():
    # connection parameters - ENTER YOUR LOGIN AND PASSWORD HERE
    database = "y24s1c9120_czho6150"
    userid = "y24s1c9120_czho6150"
    passwd = "aKFb7tC9"
    myHost = "awsprddbs4836.shared.sydney.edu.au"

    # Create a connection to the database
    conn = None
    try:
        # Parses the config file and connects using the connect string
        conn = psycopg2.connect(database=database,
                                    user=userid,
                                    password=passwd,
                                    host=myHost)
    except psycopg2.Error as sqle:
        print("psycopg2.Error : " + sqle.pgerror)
    
    # return the connection to use
    return conn

'''
Validate staff based on username and password
'''
def checkStaffLogin(staffID, password):
    conn = openConnection()
    if conn is None:
        return None

    try:
        cur = conn.cursor()
        cur.execute("SELECT * FROM staff WHERE staffid = %s AND password = %s", (staffID, password))
        row = cur.fetchone()
        return row
    except psycopg2.Error as e:
        print("Error: ", e)
    finally:
        cur.close()
        conn.close()


'''
List all the associated menu items in the database by staff
'''
def findMenuItemsByStaff(staffID):
    conn = openConnection()
    if conn is None:
        return None
    try:
        cur = conn.cursor(cursor_factory=DictCursor)
        cur.execute("""
                    SELECT 
            mi.MenuItemID as menuitem_id,
            mi.Name as name,
            mi.Description as description,
            CONCAT_WS('|', c1.CategoryName, c2.CategoryName, c3.CategoryName) as category,
            CONCAT_WS(' - ', ct.CoffeeTypeName, mk.MilkKindName) as coffeeoption,
            mi.Price as price,
            TO_CHAR(mi.ReviewDate, 'DD-MM-YYYY') as reviewdate,
            CONCAT(s.FirstName, ' ', s.LastName) as reviewer
        FROM 
            MenuItem mi
        LEFT JOIN 
            Category c1 ON mi.CategoryOne = c1.CategoryID
        LEFT JOIN 
            Category c2 ON mi.CategoryTwo = c2.CategoryID
        LEFT JOIN 
            Category c3 ON mi.CategoryThree = c3.CategoryID
        LEFT JOIN 
            CoffeeType ct ON mi.CoffeeType = ct.CoffeeTypeID
        LEFT JOIN 
            MilkKind mk ON mi.MilkKind = mk.MilkKindID
        LEFT JOIN 
            Staff s ON mi.Reviewer = s.StaffID
            WHERE 
                mi.Reviewer = %s
            ORDER BY 
                mi.ReviewDate ASC, mi.Description ASC, mi.Price DESC
        """, (staffID,))
        rows = cur.fetchall()
        # 将 None 值替换为 ''
        rows = [{k: ("" if v is None else v) for k, v in row.items()} for row in rows]
        return rows
    except psycopg2.Error as e:
        print("Error: ", e)
    finally:
        cur.close()
        conn.close()




'''
Find a list of menu items based on the searchString provided as parameter
See assignment description for search specification
'''
def findMenuItemsByCriteria(searchString):
    # print("Searching for: ", searchString)
    conn = openConnection()
    if conn is None:
        return None

    try:
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        # Prepare the SQL query to search across multiple fields
        query = """
        SELECT 
            mi.MenuItemID as menuitem_id,
            mi.Name as name,
            mi.Description as description,
            CONCAT_WS('|', c1.CategoryName, c2.CategoryName, c3.CategoryName) as category,
            CONCAT_WS(' - ', ct.CoffeeTypeName, mk.MilkKindName) as coffeeoption,
            mi.Price as price,
            TO_CHAR(mi.ReviewDate, 'DD-MM-YYYY') as reviewdate,
            CONCAT(s.FirstName, ' ', s.LastName) as reviewer
        FROM 
            MenuItem mi
        LEFT JOIN 
            Category c1 ON mi.CategoryOne = c1.CategoryID
        LEFT JOIN 
            Category c2 ON mi.CategoryTwo = c2.CategoryID
        LEFT JOIN 
            Category c3 ON mi.CategoryThree = c3.CategoryID
        LEFT JOIN 
            coffeetype ct ON mi.CoffeeType = ct.CoffeeTypeID
        LEFT JOIN 
            MilkKind mk ON mi.MilkKind = mk.MilkKindID
        LEFT JOIN 
            Staff s ON mi.Reviewer = s.StaffID
        WHERE 
            (%s = '' OR LOWER(mi.Name) LIKE LOWER(%s) OR LOWER(mi.Description) LIKE LOWER(%s) OR 
            LOWER(c1.CategoryName) LIKE LOWER(%s) OR LOWER(c2.CategoryName) LIKE LOWER(%s) OR 
            LOWER(c3.CategoryName) LIKE LOWER(%s) OR LOWER(ct.CoffeeTypeName) LIKE LOWER(%s) OR 
            LOWER(mk.MilkKindName) LIKE LOWER(%s) OR LOWER(CONCAT(s.FirstName, ' ', s.LastName)) LIKE LOWER(%s))
        ORDER BY 
            mi.Reviewer IS NULL DESC, mi.ReviewDate DESC
        """
        like_pattern = f'%{searchString}%'
        cur.execute(query, (searchString, like_pattern, like_pattern, like_pattern, like_pattern, like_pattern, like_pattern, like_pattern, like_pattern))
        rows = cur.fetchall()
        return rows
    except psycopg2.Error as e:
        print("Error: ", e)
    finally:
        cur.close()
        conn.close()






'''
Add a new menu item
'''
def addMenuItem(name, description, categoryone, categorytwo, categorythree, coffeetype, milkkind, price):
    if milkkind and not coffeetype:
        print("Error: A coffee type must be provided when a milk kind is specified.")
        return False

    conn = openConnection()
    if conn is None:
        return False

    try:
        cursor = conn.cursor()

        categoryOneId = getIdForName("Category", "CategoryName", categoryone)
        categoryTwoId = getIdForName("Category", "CategoryName", categorytwo)
        categoryThreeId = getIdForName("Category", "CategoryName", categorythree)
        coffeeTypeId = getIdForName("CoffeeType", "CoffeeTypeName", coffeetype) if coffeetype else None
        milkKindId = getIdForName("MilkKind", "MilkKindName", milkkind) if milkkind else None

        # Inserting new menu item
        sql = """
        INSERT INTO menuitem (Name, Description, CategoryOne, CategoryTwo, CategoryThree, CoffeeType, MilkKind, Price)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (name, description, categoryOneId, categoryTwoId, categoryThreeId, coffeeTypeId, milkKindId, price))
        conn.commit()
        print("Menu item added successfully!")

    except psycopg2.Error as e:
        conn.rollback()
        print("Failed to add menu item. Error: ", e)
        return False
    finally:
        cursor.close()
        conn.close()

    return True



'''
Update an existing menu item
'''
def updateMenuItem(menuitemid, name, description, categoryone, categorytwo, categorythree, coffeetype, milkkind, price, reviewdate, reviewer):


    # Check for required parameters
    if not menuitemid or not name or categoryone is None or price is None:
        print("Error: Required fields must be provided and valid.")
        return None

    conn = openConnection()
    if conn is None:
        return None

    try:
        cur = conn.cursor()

        # Get the IDs for category, coffee type, and milk kind
        categoryOneId = getIdForName("Category", "CategoryName", categoryone)
        categoryTwoId = getIdForName("Category", "CategoryName", categorytwo)
        categoryThreeId = getIdForName("Category", "CategoryName", categorythree)
        coffeeTypeId = getIdForName("CoffeeType", "CoffeeTypeName", coffeetype) if coffeetype else None
        milkKindId = getIdForName("MilkKind", "MilkKindName", milkkind) if milkkind else None
        reviewerId = getIdForReviewer(reviewer) if reviewer else None
        # Execute the update statement
        cur.execute(
            """
            UPDATE menuitem
            SET name=%s, description=%s, categoryone=%s, categorytwo=%s, categorythree=%s, coffeetype=%s, milkkind=%s, price=%s, reviewdate=%s, reviewer=%s
            WHERE menuitemid=%s
            """,
            (name, description, categoryOneId, categoryTwoId, categoryThreeId, coffeeTypeId, milkKindId, price,
             reviewdate, reviewerId, menuitemid)
        )

        conn.commit()
        print("Menu item updated successfully!")
        return True

    except psycopg2.Error as e:
        print("Error: ", e)
        conn.rollback()
    finally:
        cur.close()
        conn.close()


def getIdForName(tableName, columnName, name):
    conn = openConnection()
    if conn is None:
        return None
    try:
        cursor = conn.cursor()
        query = f"SELECT {tableName}id FROM {tableName} WHERE {columnName} = %s LIMIT 1;"
        cursor.execute(query, (name,))
        result = cursor.fetchone()
        return result[0] if result else None
    except psycopg2.Error as e:
        print(f"Error getting ID for {name} in {tableName}: ", e)
        return None
    finally:
        cursor.close()
        conn.close()

def getIdForReviewer(fullName):
    conn = openConnection()
    if conn is None:
        return None
    try:
        cursor = conn.cursor()
        # Adjust the query to split the full name into first and last names
        query = """
        SELECT StaffID FROM Staff
        WHERE CONCAT(FirstName, ' ', LastName) = %s LIMIT 1;
        """
        cursor.execute(query, (fullName,))
        result = cursor.fetchone()
        return result[0] if result else None
    except psycopg2.Error as e:
        print(f"Error getting ID for reviewer {fullName}: ", e)
        return None
    finally:
        cursor.close()
        conn.close()
