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
('Ivo', 'Petkov', 'ivopetkov@gmail.com', '+359892783745', 'Host');
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
VALUES (1, 'Friendly host who enjoys meeting new people.', 4.8, 'Super Host');
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

SELECT * from Users.UserAccount

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

SELECT * FROM Catalog.Location
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



SELECT * FROM [Catalog].Listing

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

INSERT INTO [Catalog].[Photo]
(ListingID, PhotoURL, Caption)
VALUES
(2, N'https://example.com/images/listing-2/living-room.jpg', N'Bright living room'),
(2, N'https://example.com/images/listing-2/bedroom.jpg',     N'Cozy bedroom'),
(2, N'https://example.com/images/listing-2/kitchen.jpg',     N'Fully equipped kitchen');
GO

select * from [Catalog].Photo
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

SELECT * from amenities.Amenity
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
CREATE TRIGGER TR_Booking_CheckAvailability
ON [Reservations].[Booking]
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ListingID INT, @CheckIn DATE, @CheckOut DATE, @UserID INT, @GuestCount INT;
    SELECT 
        @ListingID = ListingID,
        @CheckIn = CheckIn,
        @CheckOut = CheckOut,
        @UserID = UserID,
        @GuestCount = GuestCount
    FROM inserted;

    IF EXISTS (
        SELECT 1 
        FROM [Reservations].[Booking] b
        WHERE b.ListingID = @ListingID
          AND (
               (@CheckIn BETWEEN b.CheckIn AND b.CheckOut)
               OR (@CheckOut BETWEEN b.CheckIn AND b.CheckOut)
               OR (b.CheckIn BETWEEN @CheckIn AND @CheckOut)
              )
    )
    BEGIN
        RAISERROR('This listing is already booked for the selected dates.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    

    DECLARE @MaxGuests INT;
    SELECT @MaxGuests = MaxGuests FROM [Catalog].[Listing] WHERE ListingID = @ListingID;
    IF @GuestCount > @MaxGuests
    BEGIN
        RAISERROR('Guest count exceeds maximum allowed guests for this listing.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

   

    DECLARE @BasePrice MONEY, @CleaningFee MONEY, @Nights INT, @Total MONEY, @Currency NVARCHAR(10);
    SELECT 
        @BasePrice = BasePrice, 
        @CleaningFee = CleaningFee,
        @Currency = Currency
    FROM [Catalog].[Listing]
    WHERE ListingID = @ListingID;

    SET @Nights = DATEDIFF(DAY, @CheckIn, @CheckOut);
    SET @Total = (@Nights * @BasePrice) + @CleaningFee;

    
    INSERT INTO [Reservations].[Booking]
    (ListingID, UserID, CheckIn, CheckOut, GuestCount, Currency, TotalPrice, StatusOfBooking)
    VALUES
    (@ListingID, @UserID, @CheckIn, @CheckOut, @GuestCount, @Currency, @Total, N'Confirmed');
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
----------------Function-------------------------

----------------Function-------------------------

CREATE FUNCTION [Availability].[ufn_FreeListingsByCity]
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
    SELECT l.ListingID, l.Title, l.MaxGuests, l.BasePrice, l.CleaningFee, loc.City, loc.Country
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
----------------Function-------------------------

INSERT INTO [Reservations].[Booking]
(ListingID, UserID, CheckIn, CheckOut, GuestCount)
VALUES
(2, 1, '2025-11-05', '2025-11-10', 2);
GO

SELECT * FROM [Reservations].[Booking];

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

SELECT * from Reservations.Review
-------------Reservations.Review---------------------

-------------Billing.Payment---------------------
CREATE TABLE [Billing].[Payment]
(
   PaymentID INT IDENTITY(1,1) NOT NULL,
   BookingID INT NOT NULL,
   Method NVARCHAR(40) NOT NULL,
   Amount MONEY NOT NULL
       CONSTRAINT CK_Payment_Amount_Positive CHECK (Amount > 0),
   Currency CHAR(3) NOT NULL, -- 'BGN','EUR','USD' (по-стегнато от NVARCHAR(15))
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
select * from billing.Payment
-------------Billing.Payment---------------------

