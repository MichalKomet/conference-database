-- Declaration enums
CREATE TYPE presentation_type AS ENUM ('Lecture', 'Article', 'Poster');
CREATE TYPE payment_status_type AS ENUM ('Paid', 'Unpaid', 'Exempt');
CREATE TYPE payment_amount_type AS ENUM ('0', '25', '50', '100');
CREATE TYPE presentation_status_type AS ENUM ('Not Delivered', 'Scheduled', 'Completed', 'Cancelled');
CREATE TYPE article_status_type AS ENUM ('Submitted', 'Reviewed', 'Published', 'Rejected');
-- Implement tabels
CREATE TABLE Participants
(
    Participant_ID  SERIAL PRIMARY KEY,
    Name            varchar(20),
    Surname         varchar(20),
    Title           varchar(10),
    University_Name varchar(100),
    Payment         payment_amount_type DEFAULT '0',
    Payment_Status  payment_status_type DEFAULT 'Unpaid'
);

CREATE TABLE Presentations
(
    Presentation_ID SERIAL PRIMARY KEY,
    Title           varchar(100),
    Summary         text,
    Topic_Category  varchar(100),
    Type            presentation_type,
    Duration        interval,
    Status          presentation_status_type DEFAULT 'Not Delivered'
);

CREATE TABLE Authors
(
    Author_ID       SERIAL PRIMARY KEY,
    Participant_ID  int REFERENCES Participants (Participant_ID),
    Presentation_ID int REFERENCES Presentations (Presentation_ID)
);

CREATE TABLE Rooms
(
    Room_ID           SERIAL PRIMARY KEY,
    Availability_From time,
    Availability_To   time
);

CREATE TABLE Sessions
(
    Session_ID  SERIAL PRIMARY KEY,
    Date        date,
    Start_Time  time,
    End_Time    time,
    Room_ID     int REFERENCES Rooms (Room_ID),
    Chairman_ID int REFERENCES Participants (Participant_ID)
);

CREATE TABLE Presentations_in_Session
(
    Presentation_ID int REFERENCES Presentations (Presentation_ID),
    Session_ID      int REFERENCES Sessions (Session_ID),
    Sequence        int,
    PRIMARY KEY (Session_ID, Presentation_ID)
);

CREATE TABLE Items
(
    Item_ID  SERIAL PRIMARY KEY,
    Type     varchar(20),
    Location varchar(20)
);

CREATE TABLE Items_in_Session
(
    Item_ID    int REFERENCES Items (Item_ID) UNIQUE,
    Session_ID int REFERENCES Sessions (Session_ID),
    PRIMARY KEY (Session_ID, Item_ID)
);

CREATE TABLE Keywords
(
    Keyword_ID      SERIAL PRIMARY KEY,
    Presentation_ID int REFERENCES Presentations (Presentation_ID),
    Keyword         varchar(20)
);

CREATE TABLE Articles
(
    Presentation_ID int REFERENCES Presentations (Presentation_ID),
    Pages           int,
    Status          article_status_type,
    PRIMARY KEY (Presentation_ID)
);

-- Create indexes
CREATE INDEX idx_participants ON Participants (Surname, Name);
CREATE INDEX idx_presentations ON Presentations (Title);
CREATE INDEX idx_sessions ON Sessions (Date);

-- Declaration of functions
CREATE OR REPLACE FUNCTION check_room_availability() RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Sessions
        WHERE Room_ID = NEW.Room_ID
          AND Date = NEW.Date
          AND (
              NEW.Start_Time < Sessions.End_Time
              AND NEW.End_Time > Sessions.Start_Time
          )
    ) THEN
        RAISE EXCEPTION 'Room is already in use';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_room_availability_times() RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.Availability_From >= NEW.Availability_To THEN
        RAISE EXCEPTION 'Room availability start time must be earlier than end time';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION check_presentation_duration() RETURNS TRIGGER AS
$$
DECLARE
    total_duration   interval;
    session_duration interval;
BEGIN
    SELECT SUM(Duration)
    INTO total_duration
    FROM Presentations
    WHERE Presentation_ID IN (SELECT Presentation_ID
                              FROM Presentations_in_Session
                              WHERE Session_ID = NEW.Session_ID);

    SELECT (End_Time - Start_Time)
    INTO session_duration
    FROM Sessions
    WHERE Session_ID = NEW.Session_ID;

    IF total_duration > session_duration THEN
        RAISE EXCEPTION 'The total duration of the presentation exceeds the duration of the session';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_lecture_limit() RETURNS TRIGGER AS
$$
DECLARE
    lecture_count int;
BEGIN
    SELECT COUNT(*)
    INTO lecture_count
    FROM Presentations p
             JOIN Presentations_in_Session ps ON p.Presentation_ID = ps.Presentation_ID
    WHERE ps.Session_ID = NEW.Session_ID
      AND p.Type = 'Lecture';

    IF lecture_count >= 1 AND (SELECT Type FROM Presentations WHERE Presentation_ID = NEW.Presentation_ID) = 'Lecture' THEN
        RAISE EXCEPTION 'Lecture limit per session has been exceeded';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_poster_session() RETURNS TRIGGER AS
$$
DECLARE
existing_presentation_type varchar;
BEGIN
    SELECT p.Type INTO existing_presentation_type
    FROM Presentations_in_Session ps
    JOIN Presentations p ON ps.Presentation_ID = p.Presentation_ID
    WHERE ps.Session_ID = NEW.Session_ID
    LIMIT 1;

    IF existing_presentation_type IS NOT NULL THEN
        IF existing_presentation_type != 'Poster' AND (SELECT Type FROM Presentations WHERE Presentation_ID = NEW.Presentation_ID) = 'Poster' THEN
            RAISE EXCEPTION 'Poster presentations can only be added to poster sessions';
        ELSIF existing_presentation_type = 'Poster' AND (SELECT Type FROM Presentations WHERE Presentation_ID = NEW.Presentation_ID) != 'Poster' THEN
            RAISE EXCEPTION 'Non-poster presentations cannot be added to a poster session';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_presenter_is_not_chairman() RETURNS TRIGGER AS
$$
BEGIN
    DECLARE
        new_chairman_id int;
    BEGIN
        SELECT Chairman_ID INTO new_chairman_id FROM Sessions WHERE Session_ID = NEW.Session_ID;

        IF EXISTS (SELECT 1
                   FROM Authors
                   WHERE Authors.Presentation_ID = NEW.Presentation_ID AND Authors.Participant_ID = new_chairman_id) THEN
            RAISE EXCEPTION 'Presenter cannot be the chairman of the session';
        END IF;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_fee_exemption_for_presenters() RETURNS TRIGGER AS
$$
BEGIN
    IF (SELECT Type FROM Presentations WHERE Presentation_ID = NEW.Presentation_ID) = 'Lecture' THEN
        UPDATE Participants
        SET Payment_Status = 'Exempt'
        WHERE Participant_ID = NEW.Participant_ID;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_equipment_availability() RETURNS TRIGGER AS
$$
BEGIN
    IF EXISTS(SELECT 1
              FROM Items_in_Session iis
                       JOIN Sessions S on S.Session_ID = iis.Session_ID
              WHERE iis.Item_ID = NEW.Item_ID
                AND (
                  (NEW.Session_ID != s.Session_ID) AND
                  (S.Date = (SELECT Date FROM Sessions WHERE Sessions.Session_ID = NEW.Session_ID)) AND
                  (s.Start_Time < (SELECT End_Time FROM Sessions WHERE Session_ID = NEW.Session_ID)) AND
                  (s.End_Time > (SELECT Start_Time FROM Sessions WHERE Session_ID = NEW.Session_ID))
                  )) THEN
        RAISE EXCEPTION 'This equipment is already in use at this time';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_single_presentation() RETURNS TRIGGER AS
$$
BEGIN
    IF (SELECT Type FROM Presentations WHERE Presentation_ID = NEW.Presentation_ID) IN ('Article', 'Poster') THEN
        IF EXISTS (SELECT 1
                   FROM Presentations_in_Session
                   WHERE Presentation_ID = NEW.Presentation_ID
                     AND Session_ID != NEW.Session_ID) THEN
            RAISE EXCEPTION 'Articles and posters can be presented only once';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_valid_payment() RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.Payment NOT IN ('0', '25', '50', '100') THEN
        RAISE EXCEPTION 'Invalid payment amount';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_session_dates() RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.Start_Time >= NEW.End_Time THEN
        RAISE EXCEPTION 'Session start time must be earlier then end time';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_presentation_duration() RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.Type = 'Article' THEN
        NEW.Duration := '15 minutes'::interval;
    ELSIF NEW.Type = 'Poster' THEN
        NEW.Duration := '30 minutes'::interval;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Invoke triggers
CREATE TRIGGER trigger_check_room_availability
    BEFORE INSERT OR UPDATE
    ON Sessions
    FOR EACH ROW
EXECUTE FUNCTION check_room_availability();

CREATE TRIGGER trigger_check_room_availability_times
    BEFORE INSERT OR UPDATE
    ON Rooms
    FOR EACH ROW
EXECUTE FUNCTION check_room_availability_times();

CREATE TRIGGER trigger_check_presentation_duration
    BEFORE INSERT OR UPDATE
    ON Presentations_in_Session
    FOR EACH ROW
EXECUTE FUNCTION check_presentation_duration();

CREATE TRIGGER trigger_check_poster_session
    BEFORE INSERT OR UPDATE
    ON Presentations_in_Session
    FOR EACH ROW
EXECUTE FUNCTION check_poster_session();

CREATE TRIGGER trigger_check_lecture_limit
    BEFORE INSERT
    ON Presentations_in_Session
    FOR EACH ROW
EXECUTE FUNCTION check_lecture_limit();

CREATE TRIGGER trigger_check_presenter_is_not_chairman
    BEFORE INSERT OR UPDATE
    ON Presentations_in_Session
    FOR EACH ROW
EXECUTE FUNCTION check_presenter_is_not_chairman();

CREATE TRIGGER trigger_check_fee_exemption_for_presenters
    AFTER INSERT OR UPDATE
    ON Authors
    FOR EACH ROW
EXECUTE FUNCTION check_fee_exemption_for_presenters();

CREATE TRIGGER trigger_check_equipment_availability
    AFTER INSERT OR UPDATE
    ON Items_in_Session
    FOR EACH ROW
EXECUTE FUNCTION check_equipment_availability();

CREATE TRIGGER trigger_check_single_presentation
    AFTER INSERT OR UPDATE
    ON Presentations_in_Session
    FOR EACH ROW
EXECUTE FUNCTION check_single_presentation();

CREATE TRIGGER trigger_check_valid_payment
    BEFORE INSERT OR UPDATE
    ON Participants
    FOR EACH ROW
EXECUTE FUNCTION check_valid_payment();

CREATE TRIGGER trigger_check_session_dates
    BEFORE INSERT OR UPDATE
    ON Sessions
    FOR EACH ROW
EXECUTE FUNCTION check_session_dates();

CREATE TRIGGER trigger_set_presentation_duration
    BEFORE INSERT OR UPDATE
    ON Presentations
    FOR EACH ROW
EXECUTE FUNCTION set_presentation_duration();
