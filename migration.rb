class FyiMigration
  def load(model)
    yaml = YAML::load_file("test/#{model}.yml")
    yaml.map(&:second)
  end

  def load_users
    users = self.load('users')

    users.each{|attrs|
      user = User.new(attrs.except(*%w(profile_photo_id)))
      user[:id] = attrs["id"]
      user.save() unless /mail15\.com/.match(attrs["email"]) or !/[A-Z]/.match(attrs["name"])
    }
  end

  def load_info_requests
    requests = self.load('info_requests')

    requests.each{|attrs|
      request = InfoRequest.new(attrs.except(*%w(info_request_events_count law_id)))
      request[:id] = attrs["id"]
      request.update_url_title()
      request.save() unless attrs["id"].to_i < 10
    }
  end

  def load_correspondences
    correspondences = self.load('correspondences')
    mails = self.load('raw_emails').inject({}){|memo, email|
      memo[email["id"]] = email["data_binary"]
      memo
    }

    correspondences = correspondences.sort_by{|c| c["id"].to_i }

    correspondences.each{|attrs|
      if attrs["type"] == "IncomingMessage"
        incoming_message = IncomingMessage.new(attrs.except(*%w(user_id comment_type visible cached_main_body_text incoming_message_followup_id what_doing cached_main_body_text status last_sent_at message_type body)))
        incoming_message[:id] = attrs["id"]
        email = RawEmail.new()
        email_id = attrs["raw_email_id"]
        email[:id] = email_id
        unless attrs["info_request_id"].to_i < 10
          unless RawEmail.exists?(email_id)
            incoming_message.raw_email = email
            email.incoming_message = incoming_message
            email.data = mails[email_id]
            email.save()
          end
          result = incoming_message.save()
          raise "xxx" unless result
        end
      elsif attrs["type"] == "OutgoingMessage"
        outgoing_message = OutgoingMessage.new(attrs.except(*%w(user_id cached_attachment_text_clipped raw_email_id comment_type cached_main_body_text visible)))
        outgoing_message[:id] = attrs["id"]
        unless attrs["info_request_id"].to_i < 10
          result = outgoing_message.save()
          raise "xxx" unless result
        end
      elsif attrs["type"] == "Comment"
        comment = Comment.new(attrs)
        comment[:id] = attrs["id"]
        result = comment.save()
        raise "xxx" unless result
      end
    }
  end

  def load_events
    events = self.load('info_request_events')
    events.each{|attrs|
      c_id = attrs["correspondence_id"]
      event = InfoRequestEvent.new(attrs.except(*%w(correspondence_type correspondence_id)))
      event[:id] = attrs["id"]

      if IncomingMessage.exists?(c_id)
        incoming_message = IncomingMessage.find(c_id)
        event.incoming_message = incoming_message
        event.info_request = incoming_message.info_request
        raise "xxx" unless event.save()
      else
        begin
          event.outgoing_message = OutgoingMessage.find(c_id)
          event.info_request = event.outgoing_message.info_request
          raise "xxx" unless event.save()
        rescue
        end
      end
    }
  end

  def load_public_bodies
    bodies = self.load('public_bodies')
    bodies.each{|attrs|
      body = PublicBody.new(attrs.except(*%w(active info_requests_count short_name law_id charity_number category_id)))
      body[:id] = attrs["id"]
      body.short_name = attrs["short_name"].to_s
      raise "xxx" unless body.save()
    }
  end

  def clean
    [TrackThing, InfoRequestEvent, OutgoingMessage, IncomingMessage, RawEmail, InfoRequest, User, PublicBody].each{|c|
      c.find(:all).each(&:destroy)
    }
  end

  def run
    migration = FyiMigration.new()
    migration.clean()
    migration.load_public_bodies()
    migration.load_users()
    migration.load_info_requests()
    migration.load_correspondences()
    migration.load_events()
  end
end

FyiMigration.new().run()
