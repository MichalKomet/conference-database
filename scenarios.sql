-- Insert participant with correctly payment
INSERT INTO Participants (Name, Surname, Title, University_Name, Payment, Payment_Status)
VALUES ('Jan', 'Kowalski', 'Dr', 'Warsaw University', '50', 'Unpaid');

-- Insert Participant with incorrectly payment (expected error)
INSERT INTO Participants (Name, Surname, Title, University_Name, Payment, Payment_Status)
VALUES ('Anna', 'Nowak', 'Prof', 'Gdańsk University of Technology', '55', 'Unpaid');

-- Insert presentation
INSERT INTO Presentations (Title, Summary, Topic_Category, Type)
VALUES ('New aproach to AI', 'Summary...', 'IT', 'Article');

-- Insert Author
INSERT INTO Authors (Participant_id, Presentation_id)
VALUES (1,1);

-- Insert two lectures to the same session (expected error)
INSERT INTO Presentations (Title, Summary, Topic_Category, Type)
VALUES ('New researches in physic', 'Summary...', 'Physic', 'Lecture');

INSERT INTO Sessions (Date, Start_Time, End_Time, Room_ID, Chairman_ID)
VALUES ('2024-01-30', '09:00', '15:00', 1, 2);

INSERT INTO Presentations_in_Session (Presentation_ID, Session_ID, Sequence)
VALUES (47, 36, 1);

INSERT INTO Presentations_in_Session (Presentation_ID, Session_ID, Sequence)
VALUES (47, 36, 2);

-- Insert two sessions to one room in the same time (expected error)
INSERT INTO Sessions (Date, Start_Time, End_Time, Room_ID, Chairman_ID)
VALUES ('2024-01-30', '10:00', '13:00', 1, 3);

-- Insert an article and set it's status
INSERT INTO Articles (Presentation_ID, Pages, Status)
VALUES (1, 10, 'Submitted');

UPDATE Articles
SET Status = 'Published'
WHERE Presentation_ID = 1;

-- Insert keywords related to presentations
INSERT INTO Keywords (Presentation_ID, Keyword)
VALUES (1, 'AI');

INSERT INTO Keywords (Presentation_ID, Keyword)
VALUES (1, 'machine learning');

-- Insert one item to two independent sessions (expected error)
INSERT INTO Items (Type, Location)
VALUES ('Projector', '101');

INSERT INTO Items_in_Session (Item_ID, Session_ID)
VALUES (16, 35);

INSERT INTO Items_in_Session (Item_ID, Session_ID)
VALUES (16, 36);

-- Insert Poster presentation to non-poster session (expected error)
INSERT INTO Presentations (Title, Summary, Topic_Category, Type)
VALUES ('Astral research', 'Astral research', 'Astronomy', 'Poster');

INSERT INTO Presentations_in_Session (Presentation_ID, Session_ID, Sequence)
VALUES (48, 36, 3);

-- Insert author as a chairman (expected error)
INSERT INTO Sessions (Date, Start_Time, End_Time, Room_ID, Chairman_ID)
VALUES ('2024-01-31', '09:00', '11:00', 2, 1);

INSERT INTO Presentations_in_Session (Presentation_ID, Session_ID, Sequence)
VALUES (1, 38, 1);

-- Update payment status for lecture presenters
INSERT INTO Participants (Name, Surname, Title, University_Name, Payment, Payment_Status)
VALUES ('Marek', 'Wiśniewski', 'Prof', 'AGH', '100', 'Paid');

INSERT INTO Presentations (Title, Summary, Topic_Category, Type)
VALUES ('New energy', 'Research of technologies', 'Economy', 'Lecture');

SELECT * FROM Participants WHERE Participant_ID = 52;--

INSERT INTO Authors (Participant_ID, Presentation_ID)
VALUES (52, 49);

SELECT * FROM Participants WHERE Participant_ID = 52;--

-- Check sessions at the same time but in another rooms
INSERT INTO Sessions (Date, Start_Time, End_Time, Room_ID, Chairman_ID)
VALUES ('2024-01-31', '10:00', '12:00', 3, 4);

SELECT * FROM Sessions
WHERE Date = '2024-01-31'
AND Start_Time < '12:00'
AND End_Time > '10:00';

--  List all participants
SELECT Participant_ID, Name, Surname, Title, University_Name, Payment, Payment_Status
FROM Participants;

-- List presentations with their authors
SELECT p.Title, p.Summary, p.Topic_Category, p.Type, p.Duration, p.Status,
   a.Participant_ID, pa.Name, pa.Surname
FROM Presentations p
JOIN Authors a ON p.Presentation_ID = a.Presentation_ID
JOIN Participants pa ON a.Participant_ID = pa.Participant_ID;

-- List sessions with related rooms and chairmans
SELECT s.Session_ID, s.Date, s.Start_Time, s.End_Time, s.Room_ID, r.Availability_From, r.Availability_To,
       p.Name AS Chairman_Name, p.Surname AS Chairman_Surname
FROM Sessions s
JOIN Rooms r ON s.Room_ID = r.Room_ID
JOIN Participants p ON s.Chairman_ID = p.Participant_ID;

-- List articles with their statuses
SELECT pr.Title, a.Pages, a.Status
FROM Articles a
JOIN Presentations pr ON a.Presentation_ID = pr.Presentation_ID;

-- List presentations with related keywords
SELECT p.Title, array_agg(k.Keyword) AS Keywords
FROM Presentations p
JOIN Keywords k ON p.Presentation_ID = k.Presentation_ID
GROUP BY p.Presentation_ID;

-- List sessions with related presentations
SELECT p.Presentation_ID, s.Session_ID, s.Date, s.Start_Time, s.End_Time, p.Title, pis.Sequence
FROM Sessions s
JOIN Presentations_in_Session pis ON s.Session_ID = pis.Session_ID
JOIN Presentations p ON pis.Presentation_ID = p.Presentation_ID
ORDER BY s.Session_ID, pis.Sequence;

-- List items related to sessions
SELECT i.Type, i.Location, s.Session_ID, s.Date, s.Start_Time, s.End_Time
FROM Items i
JOIN Items_in_Session iis ON i.Item_ID = iis.Item_ID
JOIN Sessions s ON iis.Session_ID = s.Session_ID;

-- List participants with "Unpaid" payment status
SELECT * FROM Participants
WHERE Payment_Status = 'Unpaid';

-- List cancelled presentations
SELECT p.Presentation_ID, p.Title, p.status
FROM Presentations p
JOIN Presentations_in_Session pis ON p.Presentation_ID = pis.Presentation_ID
WHERE p.status = 'Cancelled';

-- List presentations of the day
SELECT p.Title, s.Date
FROM Presentations p
JOIN Presentations_in_Session pis ON p.Presentation_ID = pis.Presentation_ID
JOIN Sessions s ON pis.Session_ID = s.Session_ID
WHERE s.Date = '2024-01-2';