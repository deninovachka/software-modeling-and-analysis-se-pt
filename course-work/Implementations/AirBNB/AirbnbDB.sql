CREATE DATABASE AirbnbDB
GO

USE AirbnbDB
GO

CREATE SCHEMA Users
GO

CREATE SCHEMA Hosts
GO

CREATE SCHEMA Catalog
GO

CREATE SCHEMA Amenities
GO

CREATE SCHEMA Availability
GO

CREATE SCHEMA Reservations
GO

CREATE SCHEMA Billing
GO

-------------Users.UserAccount---------------------
CREATE TABLE [Users].[UserAccount]
(
   UserID INT IDENTITY(1,1) NOT NULL,
   FirstName NVARCHAR(150) NOT NULL,
   LastName NVARCHAR(150) NOT NULL,
   Email NVARCHAR(100) NOT NULL,
   PhoneNumber NVARCHAR(50) NOT NULL,
   AccountType NVARCHAR(20) NOT NULL,  
   [State] NVARCHAR(10) NOT NULL 
        CONSTRAINT DF_UserAccount_State DEFAULT N'Active'
        CONSTRAINT CK_UserAccount_State CHECK ([State] IN (N'Active', N'Inactive')),
    CreatedAt DATETIME2(3) NOT NULL 
        CONSTRAINT DF_UserAccount_CreatedAt DEFAULT SYSUTCDATETIME(),
   LastLoginAt   DATETIME2(3) NULL, 
   DeactivatedAt DATETIME2(3) NULL, 

    CONSTRAINT PK_UserAccount_UserId PRIMARY KEY(UserId),
    CONSTRAINT UQ_UserAccount_Email UNIQUE(Email)
);
GO

EXEC sys.sp_addextendedproperty
@name=N'TableDescription',
@value=N'Table is used for storing user account information (both guests and hosts).',
@level0type=N'SCHEMA',
@level0name=N'Users',
@level1type=N'TABLE',
@level1name=N'UserAccount';
GO

INSERT INTO [Users].[UserAccount]
(FirstName, LastName, Email, PhoneNumber, AccountType)
VALUES
(N'Aleks', N'Tomov', N'alekstomov@gmail.com', N'+359871234567', N'Guest'),
(N'Maria', N'Ivanova', N'maria.ivanova@gmail.com', N'+359882345678', N'Host'),
(N'Georgi', N'Dimitrov', N'georgi.dimitrov@gmail.com', N'+359883456789', N'Guest'),
(N'Elena', N'Koleva', N'elena.koleva@gmail.com', N'+359884567890', N'Guest');
GO

------------Procedure--------------
CREATE PROCEDURE [Users].[DeactivateInactiveUsers]
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [Users].[UserAccount]
    SET [State] = N'Inactive',
        DeactivatedAt = SYSUTCDATETIME()
    WHERE [State] = N'Active'
      AND (LastLoginAt IS NULL OR LastLoginAt < DATEADD(DAY, -90, SYSUTCDATETIME()));
END;
GO
------------Procedure--------------

UPDATE [Users].[UserAccount]
SET LastLoginAt = SYSUTCDATETIME()
WHERE UserID = 2;


UPDATE [Users].[UserAccount]
SET LastLoginAt = DATEADD(DAY, -120, SYSUTCDATETIME())
WHERE Email = 'petarpetrov@gmail.com';
EXEC [Users].[DeactivateInactiveUsers];
SELECT UserID, Email, State, LastLoginAt, DeactivatedAt
FROM [Users].[UserAccount];


ALTER TABLE [Users].[UserAccount]
ADD CONSTRAINT UQ_UserAccount_PhoneNumber UNIQUE(PhoneNumber);
GO

-------------Users.UserAccount---------------------

-------------Hosts.HostProfile---------------------
CREATE TABLE [Hosts].[HostProfile]
(
   HostID INT IDENTITY(1,1) NOT NULL,
   UserID INT NOT NULL,
   About NVARCHAR(500) NOT NULL,
   ResponseRate DECIMAL(2,1) NULL
        CONSTRAINT CK_HostProfile_ResponseRate CHECK (ResponseRate BETWEEN 0.0 AND 5.0),
   HostType NVARCHAR(30) NOT NULL
        CONSTRAINT CK_HostProfile_HostType CHECK (HostType IN (N'Host', N'Super Host')),
   JoinedAt DATETIME2(3) NOT NULL 
        CONSTRAINT DF_HostProfile_JoinedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_HostProfile_HostID PRIMARY KEY (HostID),
    CONSTRAINT FK_Users_UserAccount_UserId FOREIGN KEY(UserID) REFERENCES Users.UserAccount(UserID),

    CONSTRAINT UQ_HostProfile_UserID UNIQUE (UserID)
);
GO

EXEC sys.sp_addextendedproperty
@name=N'TableDescription',
@value=N'Table is used for storing host account information.',
@level0type=N'SCHEMA',
@level0name=N'Hosts',
@level1type=N'TABLE',
@level1name=N'HostProfile';
GO


INSERT INTO [Hosts].[HostProfile]
(UserID, About, ResponseRate, HostType)
VALUES
(2, N'I am a calm and responsible host.', 4.6, N'Host'),
(3, N'I enjoy providing cozy spaces for travelers.', 4.9, N'Super Host');
GO

-------Trigger-------------
CREATE TRIGGER [Hosts].[tr_UpdateAccountType_OnHostCreate]
ON [Hosts].[HostProfile]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ua
    SET ua.AccountType =
        CASE 
            WHEN ua.AccountType = N'Guest' THEN N'Both'
            ELSE ua.AccountType
        END
    FROM [Users].[UserAccount] ua
    INNER JOIN inserted i ON ua.UserID = i.UserID;
END;
GO
-------Trigger-------------

-------Trigger-------------
CREATE TRIGGER [Hosts].[tr_UpdateAccountType_OnHostDelete]
ON [Hosts].[HostProfile]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE ua
    SET ua.AccountType = N'Guest'
    FROM [Users].[UserAccount] ua
    INNER JOIN deleted d ON ua.UserID = d.UserID;
END;
GO
-------Trigger-------------


SELECT ua.UserID, ua.AccountType, hp.HostID, hp.HostType, hp.ResponseRate
FROM [Users].[UserAccount] ua
JOIN [Hosts].[HostProfile] hp ON hp.UserID = ua.UserID
WHERE ua.UserID = 1;


DELETE FROM [Hosts].[HostProfile] WHERE UserID = 1;
SELECT UserID, AccountType FROM [Users].[UserAccount] WHERE UserID = 1;


-------------Hosts.HostProfile---------------------

-------------Catalog.Location---------------------
CREATE TABLE [Catalog].[Location]
(
   LocationID INT IDENTITY(1,1) NOT NULL,
   City NVARCHAR(200) NOT NULL,
   Region NVARCHAR(200) NOT NULL,
   Country NVARCHAR(200) NOT NULL,
   Latitude DECIMAL(9,6) NOT NULL,
   Longitude DECIMAL(9,6) NOT NULL,

    LatitudeHemisphere AS 
       CASE 
           WHEN Latitude > 0 THEN N'Northern'
           WHEN Latitude < 0 THEN N'Southern'
           ELSE N'Equator'
       END PERSISTED,

   LongitudeHemisphere AS 
       CASE 
           WHEN Longitude > 0 THEN N'Eastern'
           WHEN Longitude < 0 THEN N'Western'
           ELSE N'Prime Meridian'
       END PERSISTED,

    CONSTRAINT PK_Location_LocationID PRIMARY KEY (LocationID),
    
    CONSTRAINT UQ_Location_LatLong UNIQUE (Latitude, Longitude)
);
GO

EXEC sys.sp_addextendedproperty
@name=N'TableDescription',
@value=N'Table is used for storing location information.',
@level0type=N'SCHEMA',
@level0name=N'Catalog',
@level1type=N'TABLE',
@level1name=N'Location';
GO

INSERT INTO [Catalog].[Location]
(City, Region, Country, Latitude, Longitude)
VALUES
(N'Sofia', N'Sofia City', N'Bulgaria', 42.6977, 23.3219),      
(N'London', N'England', N'United Kingdom', 51.5072, -0.1276),   
(N'Sydney', N'New South Wales', N'Australia', -33.8688, 151.2093), 
(N'New York', N'New York', N'USA', 40.7128, -74.0060),          
(N'Quito', N'Pichincha', N'Ecuador', 0.0000, -78.4550);         
GO

INSERT INTO [Catalog].[Location]
(City, Region, Country, Latitude, Longitude)
VALUES
(N'Rome', N'Lazio', N'Italy', 41.9028, 12.4964),
(N'Barcelona', N'Catalonia', N'Spain', 41.3851, 2.1734),
(N'Amsterdam', N'North Holland', N'Netherlands', 52.3676, 4.9041),
(N'Toronto', N'Ontario', N'Canada', 43.6532, -79.3832),
(N'Cape Town', N'Western Cape', N'South Africa', -33.9249, 18.4241),
(N'Dubai', N'Dubai', N'United Arab Emirates', 25.276987, 55.296249),
(N'Singapore', N'Singapore', N'Singapore', 1.3521, 103.8198),
(N'Rio de Janeiro', N'Rio de Janeiro', N'Brazil', -22.9068, -43.1729),
(N'Tokyo', N'Tokyo', N'Japan', 35.6764, 139.6500),
(N'Istanbul', N'Istanbul', N'Turkey', 41.0082, 28.9784);
GO
-------------Catalog.Location---------------------

-------------Catalog.Listing---------------------
CREATE TABLE [Catalog].[Listing]
(
   ListingID INT IDENTITY(1,1) NOT NULL,
   HostID INT NOT NULL,
   LocationID INT NOT NULL,
   Title NVARCHAR(200) NOT NULL,
   DescriptionListing NVARCHAR(MAX) NOT NULL,
   PropertyType NVARCHAR(50) NOT NULL,
   MaxGuests INT NOT NULL
       CONSTRAINT DF_Listing_MaxGuests DEFAULT (1),
   Bedrooms INT NOT NULL
       CONSTRAINT DF_Listing_Bedrooms DEFAULT (1),
   Beds INT NOT NULL
       CONSTRAINT DF_Listing_Beds DEFAULT (1),
   Bathrooms INT NOT NULL
       CONSTRAINT DF_Listing_Bathrooms DEFAULT (1),
   BasePrice MONEY NOT NULL,
   CleaningFee MONEY NOT NULL,
   Currency NVARCHAR(15) NOT NULL,

    CONSTRAINT PK_Listing_ListingID PRIMARY KEY (ListingID),
    CONSTRAINT FK_Hosts_HostProfile_HostID FOREIGN KEY(HostID) REFERENCES Hosts.HostProfile(HostID),
    CONSTRAINT FK_Catalog_Location_LocationID FOREIGN KEY(LocationID) REFERENCES Catalog.Location(LocationID),

);
GO

EXEC sys.sp_addextendedproperty
@name=N'TableDescription',
@value=N'Table is used for storing listing information.',
@level0type=N'SCHEMA',
@level0name=N'Catalog',
@level1type=N'TABLE',
@level1name=N'Listing';
GO

INSERT INTO [Catalog].[Listing]
(HostID, LocationID, Title, DescriptionListing, PropertyType, MaxGuests, Bedrooms, Beds, Bathrooms, BasePrice, CleaningFee, Currency)
VALUES
(2, 1, 
 N'Cozy Apartment', 
 N'A modern and cozy apartment located near the city center, perfect for short stays.',
 N'Apartment',
 2, 1, 1, 1, 150, 20, 
 N'BGN');
GO

INSERT INTO [Catalog].[Listing]
(HostID, LocationID, Title, DescriptionListing, PropertyType, MaxGuests, Bedrooms, Beds, Bathrooms, BasePrice, CleaningFee, Currency)
VALUES

(2, 2,
 N'Central Flat near Hyde Park',
 N'Bright apartment a short walk from Hyde Park; perfect for city breaks.',
 N'Apartment',
 3, 1, 2, 1, 220, 30, N'GBP'),

(3, 10,
 N'Canal Loft with Balcony',
 N'Minimalist loft overlooking a quiet canal; cafes and bikes at your door.',
 N'Loft',
 4, 2, 3, 2, 280, 35, N'EUR'),

(6, 13,
 N'Marina View Condo',
 N'High-rise condo with pool access and quick walk to the beach.',
 N'Condo',
 5, 2, 3, 2, 600, 50, N'AED'),

(7, 14,
 N'Skyline Studio Downtown',
 N'Compact studio with city skyline views; ideal for business travelers.',
 N'Studio',
 2, 1, 1, 1, 240, 20, N'SGD'),

(3, 11,
 N'Downtown Condo by CN Tower',
 N'Modern condo with workspace and garage; steps from entertainment district.',
 N'Condo',
 4, 2, 3, 1, 260, 25, N'CAD'),

(2, 12,
 N'Sea View Family Villa',
 N'Spacious villa with terrace and barbecue; perfect for families and groups.',
 N'Villa',
 8, 4, 5, 3, 700, 60, N'ZAR'),

(6, 16,
 N'Modern Apartment in Shibuya',
 N'Quiet unit near Shibuya Station; convenience stores and metro nearby.',
 N'Apartment',
 3, 1, 2, 1, 230, 30, N'JPY'),

(7, 9,
 N'Rambla Corner Flat',
 N'Stylish flat with balcony near La Rambla; great for remote work.',
 N'Flat',
 3, 1, 2, 1, 210, 25, N'EUR');
GO
SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @D TABLE
(
    ListingID   INT PRIMARY KEY,
    Title       NVARCHAR(200),
    HostID      INT,
    LocationID  INT,
    RN          INT
);

INSERT INTO @D(ListingID, Title, HostID, LocationID, RN)
SELECT
    ListingID, Title, HostID, LocationID,
    ROW_NUMBER() OVER (PARTITION BY Title, HostID, LocationID ORDER BY ListingID)
FROM [Catalog].[Listing];

DECLARE @Keepers TABLE
(
    Title       NVARCHAR(200),
    HostID      INT,
    LocationID  INT,
    ListingID   INT PRIMARY KEY
);

INSERT INTO @Keepers(Title,HostID,LocationID,ListingID)
SELECT Title, HostID, LocationID, ListingID
FROM @D
WHERE RN = 1;

DECLARE @Dupes TABLE
(
    ListingID   INT PRIMARY KEY,
    Title       NVARCHAR(200),
    HostID      INT,
    LocationID  INT
);

-------------Catalog.Listing---------------------

-------------Catalog.Photo---------------------
CREATE TABLE [Catalog].[Photo]
(
   PhotoID INT IDENTITY(1,1) NOT NULL,
   ListingID INT NOT NULL,
   PhotoURL NVARCHAR(MAX) NOT NULL,
   Caption NVARCHAR(200) NOT NULL,
   
    CONSTRAINT PK_Photo_PhotoID PRIMARY KEY (PhotoID),
    CONSTRAINT FK_Catalog_Listing_ListingID FOREIGN KEY(ListingID) REFERENCES Catalog.Listing(ListingID)
);
GO

EXEC sys.sp_addextendedproperty
@name=N'TableDescription',
@value=N'Table is used for storing photos information.',
@level0type=N'SCHEMA',
@level0name=N'Catalog',
@level1type=N'TABLE',
@level1name=N'Photo';
GO

INSERT INTO [Catalog].[Photo] (ListingID, PhotoURL, Caption)
VALUES

(10, N'https://cdn.airbnb-sample.com/london/living-room.jpg', N'Bright living room with large windows'),
(10, N'https://cdn.airbnb-sample.com/london/bedroom.jpg', N'Cozy bedroom with king-size bed'),
(10, N'https://cdn.airbnb-sample.com/london/view.jpg', N'Beautiful view towards Hyde Park'),

(11, N'https://cdn.airbnb-sample.com/amsterdam/living-area.jpg', N'Modern living area overlooking the canal'),
(11, N'https://cdn.airbnb-sample.com/amsterdam/balcony.jpg', N'Balcony with morning sunlight'),
(11, N'https://cdn.airbnb-sample.com/amsterdam/kitchen.jpg', N'Fully equipped open kitchen'),

(12, N'https://cdn.airbnb-sample.com/dubai/lobby.jpg', N'Luxury condo lobby with marble floor'),
(12, N'https://cdn.airbnb-sample.com/dubai/marina-view.jpg', N'Balcony with panoramic marina view'),
(12, N'https://cdn.airbnb-sample.com/dubai/bedroom.jpg', N'Spacious bedroom with skyline view'),

(13, N'https://cdn.airbnb-sample.com/singapore/skyline-night.jpg', N'Night skyline view from the window'),
(13, N'https://cdn.airbnb-sample.com/singapore/room.jpg', N'Minimalist modern studio interior'),

(14, N'https://cdn.airbnb-sample.com/toronto/living-room.jpg', N'Living room with workspace and TV'),
(14, N'https://cdn.airbnb-sample.com/toronto/view.jpg', N'Balcony view of CN Tower'),
(14, N'https://cdn.airbnb-sample.com/toronto/kitchen.jpg', N'Open kitchen with dining area'),

(15, N'https://cdn.airbnb-sample.com/capetown/pool.jpg', N'Private pool with sea view'),
(15, N'https://cdn.airbnb-sample.com/capetown/terrace.jpg', N'Spacious terrace with outdoor dining'),
(15, N'https://cdn.airbnb-sample.com/capetown/living-room.jpg', N'Large living area with fireplace'),

(16, N'https://cdn.airbnb-sample.com/tokyo/living-room.jpg', N'Small but stylish living room'),
(16, N'https://cdn.airbnb-sample.com/tokyo/bedroom.jpg', N'Compact bedroom with city view'),
(16, N'https://cdn.airbnb-sample.com/tokyo/bathroom.jpg', N'Modern Japanese bathroom'),

(17, N'https://cdn.airbnb-sample.com/barcelona/living-room.jpg', N'Spacious living room with natural light'),
(17, N'https://cdn.airbnb-sample.com/barcelona/balcony.jpg', N'Balcony overlooking La Rambla'),
(17, N'https://cdn.airbnb-sample.com/barcelona/kitchen.jpg', N'Bright kitchen with dining table');
GO

SELECT ListingID, Title, HostID, LocationID
FROM [Catalog].[Listing]
ORDER BY ListingID;

select * from catalog.listing
-------------Catalog.Photo---------------------

-------------Amenities.Amenity---------------------
CREATE TABLE [Amenities].[Amenity]
(
   AmenityID INT IDENTITY(1,1) NOT NULL,
   AmenityName NVARCHAR(150) NOT NULL,
   Category NVARCHAR(150) NOT NULL,
   
    CONSTRAINT PK_Amenity_AmenityID PRIMARY KEY (AmenityID),
    CONSTRAINT UQ_Amenity_AmenityName UNIQUE (AmenityName)
);
GO

EXEC sys.sp_addextendedproperty
@name=N'TableDescription',
@value=N'Table is used for storing amenity information.',
@level0type=N'SCHEMA',
@level0name=N'Amenities',
@level1type=N'TABLE',
@level1name=N'Amenity';
GO

INSERT INTO [Amenities].[Amenity]
(AmenityName, Category)
VALUES
(N'Wi-Fi',              N'Connectivity'),
(N'Parking',            N'Transport'),
(N'Air conditioning',   N'Climate'),
(N'Kitchen',            N'Facilities'),
(N'Washing machine',    N'Appliances'),
(N'TV',                 N'Entertainment');
GO

-------------Amenities.Amenity---------------------

-------------Amenities.ListingAmenity---------------------
CREATE TABLE [Amenities].[ListingAmenity]
(
   ListingID  INT NOT NULL,
   AmenityID  INT NOT NULL,
   AddedAt    DATETIME2(3) NOT NULL 
     CONSTRAINT DF_ListingAmenity_AddedAt DEFAULT SYSUTCDATETIME(),

   CONSTRAINT PK_ListingAmenity PRIMARY KEY (ListingID, AmenityID),

   CONSTRAINT FK_ListingAmenity_Listing
        FOREIGN KEY (ListingID) REFERENCES [Catalog].[Listing](ListingID)
        ON DELETE CASCADE,

    CONSTRAINT FK_ListingAmenity_Amenity
        FOREIGN KEY (AmenityID) REFERENCES [Amenities].[Amenity](AmenityID)
        ON DELETE CASCADE
);
GO

EXEC sys.sp_addextendedproperty
@name=N'TableDescription',
@value=N'any-to-many relation between listings and amenities.',
@level0type=N'SCHEMA',
@level0name=N'Amenities',
@level1type=N'TABLE',
@level1name=N'ListingAmenity';
GO

INSERT INTO [Amenities].[ListingAmenity] (ListingID, AmenityID)
VALUES
(2, (SELECT AmenityID FROM [Amenities].[Amenity] WHERE AmenityName = N'Wi-Fi')),
(2, (SELECT AmenityID FROM [Amenities].[Amenity] WHERE AmenityName = N'Kitchen')),
(2, (SELECT AmenityID FROM [Amenities].[Amenity] WHERE AmenityName = N'Air conditioning'));
GO

SELECT l.ListingID, l.Title, a.AmenityName
FROM [Amenities].[ListingAmenity] la
JOIN [Catalog].[Listing]   l ON l.ListingID = la.ListingID
JOIN [Amenities].[Amenity] a ON a.AmenityID = la.AmenityID
WHERE l.ListingID = 2;
-------------Amenities.ListingAmenity---------------------

-------------Reservations.Booking---------------------
CREATE TABLE [Reservations].[Booking]
(
    BookingID INT IDENTITY(1,1) NOT NULL,
    ListingID INT NOT NULL,
    UserID INT NOT NULL,
    CheckIn DATE NOT NULL,
    CheckOut DATE NOT NULL,
    GuestCount INT NOT NULL,
    Nights AS DATEDIFF(DAY, CheckIn, CheckOut) PERSISTED,
    TotalPrice MONEY NULL,
    Currency NVARCHAR(15) NOT NULL,
    StatusOfBooking NVARCHAR(50) NOT NULL 
        CONSTRAINT DF_Booking_Status DEFAULT N'Pending',
    CreatedAt DATETIME2(3) NOT NULL 
        CONSTRAINT DF_Booking_CreatedAt DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Booking_BookingID PRIMARY KEY (BookingID),

    CONSTRAINT FK_Booking_Listing FOREIGN KEY (ListingID) REFERENCES [Catalog].[Listing](ListingID),
    CONSTRAINT FK_Booking_User FOREIGN KEY (UserID) REFERENCES [Users].[UserAccount](UserID)
);
GO

EXEC sys.sp_addextendedproperty
@name=N'TableDescription',
@value=N'Table for storing user reservations (bookings).',
@level0type=N'SCHEMA',
@level0name=N'Reservations',
@level1type=N'TABLE',
@level1name=N'Booking';
GO

-----------------Trigger-----------------
ALTER TRIGGER [Reservations].[TR_Booking_CheckAvailability]
ON [Reservations].[Booking]
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN [Reservations].[Booking] b
          ON b.ListingID = i.ListingID
         AND i.CheckIn  <  b.CheckOut
         AND b.CheckIn  <  i.CheckOut
    )
    BEGIN
        RAISERROR('There is an overlapping booking for at least one of the inserted rows.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN [Catalog].[Listing] l ON l.ListingID = i.ListingID
        WHERE i.GuestCount > l.MaxGuests
    )
    BEGIN
        RAISERROR('Guest count exceeds MaxGuests for at least one of the inserted rows.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    INSERT INTO [Reservations].[Booking]
        (ListingID, UserID, CheckIn, CheckOut, GuestCount, Currency, TotalPrice, StatusOfBooking)
    SELECT
        i.ListingID,
        i.UserID,
        i.CheckIn,
        i.CheckOut,
        i.GuestCount,
        l.Currency,
        (DATEDIFF(DAY, i.CheckIn, i.CheckOut) * l.BasePrice) + l.CleaningFee AS TotalPrice,
        N'Confirmed' AS StatusOfBooking
    FROM inserted i
    JOIN [Catalog].[Listing] l ON l.ListingID = i.ListingID;
END;
GO

-----------------Trigger-----------------

-----------------Procedure------------------
CREATE PROCEDURE [Catalog].[SearchListingsByCityAndDates]
    @City NVARCHAR(200),
    @CheckIn DATE,
    @CheckOut DATE,
    @MinGuests INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT l.ListingID, l.Title, l.PropertyType, l.MaxGuests, l.BasePrice, l.CleaningFee, loc.City, loc.Country
    FROM [Catalog].[Listing] l
    JOIN [Catalog].[Location] loc ON loc.LocationID = l.LocationID
    WHERE loc.City = @City
      AND l.MaxGuests >= @MinGuests
      AND NOT EXISTS (
          SELECT 1
          FROM [Reservations].[Booking] b
          WHERE b.ListingID = l.ListingID
            AND @CheckIn < b.CheckOut
            AND b.CheckIn < @CheckOut
      );
END;
GO

EXEC [Catalog].[SearchListingsByCityAndDates]
    @City = N'London',
    @CheckIn = '2025-12-10',
    @CheckOut = '2025-12-12',
    @MinGuests = 2;

EXEC [Catalog].[SearchListingsByCityAndDates]
@City = N'Barcelona',
@CheckIn = '2025-11-23',
@CheckOut = '2025-11-25',
@MinGuests = 2;

----------------Procedure------------------------

----------------Function-------------------------
CREATE FUNCTION [Reservations].[fn_CalcStayTotal]
(
    @ListingID INT,
    @CheckIn DATE,
    @CheckOut DATE
)
RETURNS MONEY
AS
BEGIN
    DECLARE @Total MONEY;

    SELECT @Total = (DATEDIFF(DAY, @CheckIn, @CheckOut) * BasePrice) + CleaningFee
    FROM [Catalog].[Listing]
    WHERE ListingID = @ListingID;

    RETURN @Total;
END;
GO

SELECT 
    b.BookingID, b.ListingID, l.Title,
    b.CheckIn, b.CheckOut,
    [Reservations].[fn_CalcStayTotal](b.ListingID, b.CheckIn, b.CheckOut) AS CalculatedTotal,
    b.TotalPrice AS StoredTotal, b.Currency
FROM [Reservations].[Booking] b
JOIN [Catalog].[Listing] l ON l.ListingID = b.ListingID
ORDER BY b.BookingID;
----------------Function-------------------------

----------------Function-------------------------

CREATE FUNCTION [Reservations].[ufn_FreeListingsByCity]
(
    @City NVARCHAR(200),
    @CheckIn DATE,
    @CheckOut DATE,
    @MinGuests INT = 1
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        l.ListingID,
        l.Title,
        l.MaxGuests,
        l.BasePrice,
        l.CleaningFee,
        loc.City,
        loc.Country
    FROM [Catalog].[Listing] l
    JOIN [Catalog].[Location] loc ON loc.LocationID = l.LocationID
    WHERE loc.City = @City
      AND l.MaxGuests >= @MinGuests
      AND NOT EXISTS (
          SELECT 1
          FROM [Reservations].[Booking] b
          WHERE b.ListingID = l.ListingID
            AND @CheckIn < b.CheckOut
            AND b.CheckIn < @CheckOut
      )
);
GO

SELECT *
FROM [Reservations].[ufn_FreeListingsByCity](N'Barcelona', '2025-11-30', '2025-12-05', 2);
GO

----------------Function-------------------------

INSERT INTO [Reservations].[Booking]
(ListingID, UserID, CheckIn, CheckOut, GuestCount)
VALUES
(2, 1, '2025-11-05', '2025-11-10', 2);
GO

INSERT INTO [Reservations].[Booking]
(ListingID, UserID, CheckIn, CheckOut, GuestCount)
VALUES
(10, 2, '2025-12-01', '2025-12-06', 2),

(11, 3, '2025-11-20', '2025-11-24', 3),

(12, 5, '2025-12-10', '2025-12-14', 4),

(13, 9, '2025-11-28', '2025-12-01', 1),

(14, 8, '2025-12-05', '2025-12-09', 2),

(15, 4, '2025-12-18', '2025-12-24', 5),

(16, 10, '2025-12-12', '2025-12-15', 2)
GO



INSERT INTO [Reservations].[Booking]
(ListingID, UserID, CheckIn, CheckOut, GuestCount)
VALUES (2, 1, '2025-11-07', '2025-11-09', 2);

INSERT INTO [Reservations].[Booking]
(ListingID, UserID, CheckIn, CheckOut, GuestCount)
VALUES (2, 1, '2025-12-01', '2025-12-05', 10);



-------------Reservations.Booking---------------------

-------------Reservations.Review---------------------
CREATE TABLE [Reservations].[Review]
(
   ReviewID INT IDENTITY(1,1) NOT NULL,
   BookingID INT NOT NULL,
   RatingOverall DECIMAL(2,1) NOT NULL,
   Comment NVARCHAR(1000) NULL,
   CreatedAt DATETIME2(3) NOT NULL 
        CONSTRAINT DF_Review_CreatedAt DEFAULT SYSUTCDATETIME(),

   CONSTRAINT PK_Review_ReviewID PRIMARY KEY (ReviewID),
   CONSTRAINT UQ_Review_BookingID UNIQUE (BookingID),

   CONSTRAINT CK_Review_RatingOverall CHECK (RatingOverall BETWEEN 0.0 AND 5.0),

   CONSTRAINT FK_Review_Booking
       FOREIGN KEY (BookingID) REFERENCES [Reservations].[Booking](BookingID)
       ON DELETE CASCADE
);
GO

EXEC sys.sp_addextendedproperty
    @name  = N'TableDescription',
    @value = N'Table is used for storing a single review per booking (rating and comment).',
    @level0type = N'SCHEMA',
    @level0name = N'Reservations',
    @level1type = N'TABLE',
    @level1name = N'Review';
GO

INSERT INTO [Reservations].[Review] (BookingID, RatingOverall, Comment)
VALUES (1, 4.8, N'Great stay! Super clean and excellent location.');
GO

-------------Reservations.Review---------------------

-------------Billing.Payment---------------------
CREATE TABLE [Billing].[Payment]
(
   PaymentID INT IDENTITY(1,1) NOT NULL,
   BookingID INT NOT NULL,
   Method NVARCHAR(40) NOT NULL,
   Amount MONEY NOT NULL
       CONSTRAINT CK_Payment_Amount_Positive CHECK (Amount > 0),
   Currency NVARCHAR(15) NOT NULL, 
   PaidAt DATETIME2(3) NOT NULL
       CONSTRAINT DF_Payment_PaidAt DEFAULT SYSUTCDATETIME(),
   PaymentStatus NVARCHAR(20) NOT NULL
       CONSTRAINT DF_Payment_Status DEFAULT N'Pending'
       CONSTRAINT CK_Payment_Status CHECK (PaymentStatus IN (N'Pending', N'Succeeded', N'Failed', N'Refunded')),

   CONSTRAINT PK_Payment_PaymentID PRIMARY KEY (PaymentID),

   CONSTRAINT FK_Payment_Booking
       FOREIGN KEY (BookingID) REFERENCES [Reservations].[Booking](BookingID)
       ON DELETE CASCADE
);
GO

EXEC sys.sp_addextendedproperty
    @name  = N'TableDescription',
    @value = N'Table is used for storing payment information.',
    @level0type = N'SCHEMA',
    @level0name = N'Billing',
    @level1type = N'TABLE',
    @level1name = N'Payment';
GO


INSERT INTO [Billing].[Payment] (BookingID, Method, Amount, Currency, PaymentStatus)
VALUES
(1, N'Card', 500, 'BGN', N'Succeeded'),
(1, N'Card', 270, 'BGN', N'Succeeded');
GO
-------------Billing.Payment---------------------



