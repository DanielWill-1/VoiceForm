/*
  # Create scheduled events table

  1. New Tables
    - `scheduled_events`
      - `id` (uuid, primary key)
      - `title` (text, required)
      - `description` (text, optional)
      - `date` (date, required)
      - `time` (time, required)
      - `duration` (integer, minutes, default 60)
      - `type` (text, enum: form_review, team_meeting, training, maintenance, other)
      - `priority` (text, enum: low, medium, high)
      - `attendees` (jsonb array)
      - `location` (text, optional)
      - `form_id` (uuid, optional reference to forms)
      - `reminder_minutes` (integer, default 15)
      - `status` (text, enum: scheduled, in_progress, completed, cancelled)
      - `created_by` (uuid, references auth.users)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `scheduled_events` table
    - Add policies for authenticated users to manage their own events

  3. Performance
    - Add indexes for common query patterns
    - Add trigger for automatic updated_at timestamp
*/

-- Create the scheduled_events table
CREATE TABLE IF NOT EXISTS scheduled_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text DEFAULT '',
  date date NOT NULL,
  time time NOT NULL,
  duration integer DEFAULT 60 CHECK (duration > 0),
  type text NOT NULL DEFAULT 'other' CHECK (type IN ('form_review', 'team_meeting', 'training', 'maintenance', 'other')),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  attendees jsonb DEFAULT '[]'::jsonb,
  location text DEFAULT '',
  form_id uuid,
  reminder_minutes integer DEFAULT 15 CHECK (reminder_minutes >= 0),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
  created_by uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE scheduled_events ENABLE ROW LEVEL SECURITY;

-- Create policies for scheduled_events
CREATE POLICY "Users can view own scheduled events"
  ON scheduled_events
  FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "Users can create own scheduled events"
  ON scheduled_events
  FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update own scheduled events"
  ON scheduled_events
  FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can delete own scheduled events"
  ON scheduled_events
  FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_scheduled_events_created_by ON scheduled_events(created_by);
CREATE INDEX IF NOT EXISTS idx_scheduled_events_date ON scheduled_events(date);
CREATE INDEX IF NOT EXISTS idx_scheduled_events_status ON scheduled_events(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_events_type ON scheduled_events(type);
CREATE INDEX IF NOT EXISTS idx_scheduled_events_priority ON scheduled_events(priority);
CREATE INDEX IF NOT EXISTS idx_scheduled_events_date_time ON scheduled_events(date, time);

-- Create trigger function to automatically update updated_at timestamp
-- Only create if it doesn't already exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'update_scheduled_events_updated_at'
  ) THEN
    CREATE OR REPLACE FUNCTION update_scheduled_events_updated_at()
    RETURNS TRIGGER AS $func$
    BEGIN
      NEW.updated_at = now();
      RETURN NEW;
    END;
    $func$ LANGUAGE plpgsql;
  END IF;
END $$;

-- Create trigger to automatically update updated_at timestamp
DROP TRIGGER IF EXISTS update_scheduled_events_updated_at ON scheduled_events;
CREATE TRIGGER update_scheduled_events_updated_at
  BEFORE UPDATE ON scheduled_events
  FOR EACH ROW
  EXECUTE FUNCTION update_scheduled_events_updated_at();