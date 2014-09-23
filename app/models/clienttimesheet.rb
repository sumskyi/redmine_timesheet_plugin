class Clienttimesheet
  attr_accessor :projects_ids, :name

  # dummy order_by result
  def lft
    -1
  end

  def is_descendant_of?(any)
    false
  end

  def id
    projects_ids.first
  end

  def get_all_clients(projectsin)
    clients = {}

    projectsin.each do |project|
      project.visible_custom_field_values.each do |custom_value|
        if !custom_value.value.blank?

          if custom_value.custom_field.name == 'Client'
            unless clients[custom_value.value]
              client = Clienttimesheet.new
              client.projects_ids = []
            else
              client = clients[custom_value.value]
            end
            client.name = custom_value.value
            client.projects_ids << project.id

            clients[custom_value.value] = client
          end
        end
      end
    end

    clients.values
  end

  # this value will be rendered in select list
  def to_s
    self.name
  end

end
