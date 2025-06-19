DROP TABLE IF EXISTS MenuItem;
DROP TABLE IF EXISTS MilkKind;
DROP TABLE IF EXISTS CoffeeType;
DROP TABLE IF EXISTS Category;
DROP TABLE IF EXISTS Staff;

SET datestyle to 'ISO, DMY';

CREATE TABLE Staff
(
	StaffID		VARCHAR(10)		PRIMARY KEY,
	Password	VARCHAR(30)		NOT NULL,
	FirstName	VARCHAR(30)		NOT NULL,
	LastName	VARCHAR(30)		NOT NULL,
	Age			INTEGER			NOT NULL CHECK (Age > 21),
	Salary		DECIMAL(9,2)	NOT NULL CHECK (Salary > 0)
);

CREATE TABLE Category
(
	CategoryID		SERIAL	PRIMARY KEY,
	CategoryName	VARCHAR(10) UNIQUE NOT NULL,
	CategoryDesc	VARCHAR(40)	NOT NULL
);

CREATE TABLE CoffeeType
(
	CoffeeTypeID	SERIAL	PRIMARY KEY,
	CoffeeTypeName	VARCHAR(10) UNIQUE NOT NULL
);

CREATE TABLE MilkKind
(
	MilkKindID		SERIAL	PRIMARY KEY,
	MilkKindName	VARCHAR(10) UNIQUE NOT NULL
);

CREATE TABLE MenuItem
(
	MenuItemID		SERIAL			PRIMARY KEY,
	Name			VARCHAR(30)		NOT NULL,
	Description		VARCHAR(150),
	CategoryOne		INTEGER			NOT NULL REFERENCES Category,
	CategoryTwo		INTEGER			REFERENCES Category,
	CategoryThree	INTEGER			REFERENCES Category,
	CoffeeType		INTEGER			REFERENCES CoffeeType,
	MilkKind		INTEGER			REFERENCES MilkKind,
	Price			DECIMAL(6,2)	NOT NULL,
	ReviewDate		DATE,
	Reviewer		VARCHAR(10) 	REFERENCES Staff
);

CREATE OR REPLACE FUNCTION checkStaffLogin(_staffID VARCHAR, _password VARCHAR)
RETURNS TABLE(StaffID VARCHAR, FirstName VARCHAR, LastName VARCHAR, Age INTEGER, Salary DECIMAL) AS $$
BEGIN
    RETURN QUERY
    SELECT s.StaffID, s.FirstName, s.LastName, s.Age, s.Salary
    FROM Staff s
    WHERE s.StaffID = _staffID AND s.Password = _password;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION findMenuItemsByStaff(_staffID VARCHAR)
RETURNS TABLE(
    menuitem_id INTEGER,
    name VARCHAR,
    description VARCHAR,
    category VARCHAR,
    coffeeoption VARCHAR,
    price DECIMAL,
    reviewdate DATE,
    reviewer VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mi.MenuItemID as menuitem_id,
        mi.Name as name,
        mi.Description as description,
        CONCAT_WS('|', c1.CategoryName, c2.CategoryName, c3.CategoryName)::VARCHAR as category,
        CONCAT_WS(' - ', ct.CoffeeTypeName, mk.MilkKindName)::VARCHAR as coffeeoption,
        mi.Price as price,
        mi.ReviewDate as reviewdate,
        CONCAT(s.FirstName, ' ', s.LastName)::VARCHAR as reviewer
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
        mi.Reviewer = _staffID
    ORDER BY 
        mi.ReviewDate ASC, mi.Description ASC, mi.Price DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION findMenuItemsByCriteria(_searchString TEXT)
RETURNS TABLE(
    menuitem_id INTEGER,
    name VARCHAR,
    description VARCHAR,
    category VARCHAR,
    coffeeoption VARCHAR,
    price DECIMAL,
    reviewdate DATE,
    reviewer VARCHAR
) AS $$
BEGIN
    IF _searchString IS NULL OR _searchString = '' THEN

        RETURN QUERY
        SELECT 
            mi.MenuItemID as menuitem_id,
            mi.Name as name,
            mi.Description as description,
            CONCAT_WS('|', c1.CategoryName, c2.CategoryName, c3.CategoryName)::VARCHAR as category,
            CONCAT_WS(' - ', ct.CoffeeTypeName, mk.MilkKindName)::VARCHAR as coffeeoption,
            mi.Price as price,
            mi.ReviewDate as reviewdate,
            CONCAT(s.FirstName, ' ', s.LastName)::VARCHAR as reviewer
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
        ORDER BY 
            mi.Reviewer IS NULL DESC, mi.ReviewDate DESC;
    ELSE

        RETURN QUERY
        SELECT 
            mi.MenuItemID as menuitem_id,
            mi.Name as name,
            mi.Description as description,
            CONCAT_WS('|', c1.CategoryName, c2.CategoryName, c3.CategoryName)::VARCHAR as category,
            CONCAT_WS(' - ', ct.CoffeeTypeName, mk.MilkKindName)::VARCHAR as coffeeoption,
            mi.Price as price,
            mi.ReviewDate as reviewdate,
            CONCAT(s.FirstName, ' ', s.LastName)::VARCHAR as reviewer
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
            LOWER(mi.Name) LIKE LOWER('%' || _searchString || '%') OR
            LOWER(mi.Description) LIKE LOWER('%' || _searchString || '%') OR
            LOWER(c1.CategoryName) LIKE LOWER('%' || _searchString || '%') OR
            LOWER(c2.CategoryName) LIKE LOWER('%' || _searchString || '%') OR
            LOWER(c3.CategoryName) LIKE LOWER('%' || _searchString || '%') OR
            LOWER(ct.CoffeeTypeName) LIKE LOWER('%' || _searchString || '%') OR
            LOWER(mk.MilkKindName) LIKE LOWER('%' || _searchString || '%') OR
            LOWER(CONCAT(s.FirstName, ' ', s.LastName)) LIKE LOWER('%' || _searchString || '%')
        ORDER BY 
            mi.Reviewer IS NULL DESC, mi.ReviewDate DESC;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION addMenuItem(
    _name VARCHAR,
    _description VARCHAR,
    _categoryone VARCHAR,
    _categorytwo VARCHAR,
    _categorythree VARCHAR,
    _coffeetype VARCHAR,
    _milkkind VARCHAR,
    _price DECIMAL
)
RETURNS BOOLEAN AS $$
DECLARE
    _categoryOneId INTEGER;
    _categoryTwoId INTEGER;
    _categoryThreeId INTEGER;
    _coffeeTypeId INTEGER;
    _milkKindId INTEGER;
BEGIN

    IF _milkkind IS NOT NULL AND _coffeetype IS NULL THEN
        RAISE EXCEPTION 'Error: A coffee type must be provided when a milk kind is specified.';
        RETURN FALSE;
    END IF;


    SELECT CategoryID INTO _categoryOneId FROM Category WHERE CategoryName = _categoryone;
    SELECT CategoryID INTO _categoryTwoId FROM Category WHERE CategoryName = _categorytwo;
    SELECT CategoryID INTO _categoryThreeId FROM Category WHERE CategoryName = _categorythree;


    IF _coffeetype IS NOT NULL THEN
        SELECT CoffeeTypeID INTO _coffeeTypeId FROM CoffeeType WHERE CoffeeTypeName = _coffeetype;
    ELSE
        _coffeeTypeId := NULL; 
    END IF;

    IF _milkkind IS NOT NULL THEN
        SELECT MilkKindID INTO _milkKindId FROM MilkKind WHERE MilkKindName = _milkkind;
    ELSE
        _milkKindId := NULL; 
    END IF;

    INSERT INTO MenuItem (Name, Description, CategoryOne, CategoryTwo, CategoryThree, CoffeeType, MilkKind, Price)
    VALUES (_name, _description, _categoryOneId, _categoryTwoId, _categoryThreeId, _coffeeTypeId, _milkKindId, _price);

    RETURN TRUE;

EXCEPTION WHEN OTHERS THEN
    RAISE;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION updateMenuItem(
    _menuitemid INTEGER,
    _name TEXT,
    _description TEXT,
    _categoryone TEXT,
    _categorytwo TEXT,
    _categorythree TEXT,
    _coffeetype TEXT,
    _milkkind TEXT,
    _price NUMERIC,
    _reviewdate DATE,
    _reviewer TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    _categoryOneId INTEGER;
    _categoryTwoId INTEGER;
    _categoryThreeId INTEGER;
    _coffeeTypeId INTEGER;
    _milkKindId INTEGER;
    _reviewerId VARCHAR;
BEGIN
    -- Check for required parameters
    IF _name IS NULL OR _categoryone IS NULL OR _price IS NULL THEN
        RAISE EXCEPTION 'Error: Required fields must be provided and valid.';
        RETURN FALSE;
    END IF;

    -- Get the IDs for category, coffee type, and milk kind
    SELECT CategoryID INTO _categoryOneId FROM Category WHERE CategoryName = _categoryone;
    IF _categorytwo IS NOT NULL THEN
        SELECT CategoryID INTO _categoryTwoId FROM Category WHERE CategoryName = _categorytwo;
    END IF;
    IF _categorythree IS NOT NULL THEN
        SELECT CategoryID INTO _categoryThreeId FROM Category WHERE CategoryName = _categorythree;
    END IF;
    IF _coffeetype IS NOT NULL THEN
        SELECT CoffeeTypeID INTO _coffeeTypeId FROM CoffeeType WHERE CoffeeTypeName = _coffeetype;
    END IF;
    IF _milkkind IS NOT NULL THEN
        SELECT MilkKindID INTO _milkKindId FROM MilkKind WHERE MilkKindName = _milkkind;
    END IF;
    IF _reviewer IS NOT NULL THEN
        SELECT StaffID INTO _reviewerId FROM Staff WHERE CONCAT(FirstName, ' ', LastName) = _reviewer;
    END IF;

    -- Execute the update statement
    UPDATE MenuItem
    SET 
        Name = _name,
        Description = _description,
        CategoryOne = _categoryOneId,
        CategoryTwo = _categoryTwoId,
        CategoryThree = _categoryThreeId,
        CoffeeType = _coffeeTypeId,
        MilkKind = _milkKindId,
        Price = _price,
        ReviewDate = _reviewdate,
        Reviewer = _reviewerId
    WHERE 
        MenuItemID = _menuitemid;

    IF FOUND THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;

EXCEPTION WHEN OTHERS THEN
    RAISE;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


INSERT INTO Staff VALUES ('ajones','098','Anna','Jones',25,41000);
INSERT INTO Staff VALUES ('ganderson','987','Glen','Anderson',30,49500.80);
INSERT INTO Staff VALUES ('jwalker','876','James','Walker',22,38890.50);
INSERT INTO Staff VALUES ('janedoe','765','Jane','Doe',26,43900.20);
INSERT INTO Staff VALUES ('johndoe','654','John','Doe',22,38000);
INSERT INTO Staff VALUES ('njohnson','543','Neil','Johnson',27,4500);
INSERT INTO Staff VALUES ('nbrown','432','Nicole','Brown',41,68100.90);
INSERT INTO Staff VALUES ('rtatum','321','Robert','Tatum',39,62400);
INSERT INTO Staff VALUES ('rmarrick','210','Ryu','Marrick',36,59900.20);
INSERT INTO Staff VALUES ('tcolemen','109','Tom','Coleman',24,48000);

INSERT INTO Category VALUES (1,'Breakfast','Menu item to be offered for breakfast');
INSERT INTO Category VALUES (2,'Lunch','Menu item to be offered for lunch');
INSERT INTO Category VALUES (3,'Dinner','Menu item to be offered for dinner');

INSERT INTO CoffeeType VALUES (1,'Espresso');
INSERT INTO CoffeeType VALUES (2,'Latte');
INSERT INTO CoffeeType VALUES (3,'Cappuccino');
INSERT INTO CoffeeType VALUES (4,'LongBlack');
INSERT INTO CoffeeType VALUES (5,'ColdBrew');

INSERT INTO MilkKind VALUES (1,'Whole');
INSERT INTO MilkKind VALUES (2,'Skim');
INSERT INTO MilkKind VALUES (3,'Soy');
INSERT INTO MilkKind VALUES (4,'Almond');
INSERT INTO MilkKind VALUES (5,'Oat');

INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('French Toast','A sliced bread soaked in beaten eggs, milk, and cream, then pan-fried with butter',1,NULL,NULL,NULL,NULL,9.90,'10/01/2024','johndoe');
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('Eggs Benedict','An English muffin, toasted, and topped with bacon, poached eggs, and classic French hollandaise sauce',1,2,NULL,NULL,NULL,12.80,'18/02/2024','janedoe');
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('Poke Bowl','Cubes of marinated fish tossed over rice and topped with vegetables and Asian-inspired sauces',1,2,3,NULL,NULL,15.90,'28/02/2024','johndoe');
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('Orange Juice','A fresh, sweet, and juicy drink with orange bits made from freshly squeezed oranges',1,2,3,NULL,NULL,6.50,'01/03/2024','janedoe');
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('White Coffee','A full-flavored concentrated form of coffee served in small, strong shots with whole milk',1,2,NULL,1,1,3.50,'22/03/2024','rtatum');
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('Black Coffee',NULL,1,2,3,4,NULL,4.30,NULL,NULL);
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('Coffee Drink',NULL,1,2,NULL,3,3,3.50,'28/02/2024','johndoe');
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('Seafood Cleopatra','Salmon topped with prawns in a creamy seafood sauce. Served with salad and chips',3,NULL,NULL,NULL,NULL,25.90,'20/02/2024','johndoe');
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('Iced Coffee','A glass of cold espresso, milk, ice cubes, and a scoop of ice cream',1,2,NULL,2,1,7.60,NULL,NULL);
INSERT INTO MenuItem (Name,Description,CategoryOne,CategoryTwo,CategoryThree,CoffeeType,MilkKind,Price,ReviewDate,Reviewer) VALUES 
	('Coffee Pancake','A short stack of pancakes flecked with espresso powder and mini chocolate chips',1,NULL,NULL,NULL,NULL,8.95,'08/04/2014','janedoe');

COMMIT;