# SQLite3 configuration extensions - only loaded when using SQLite
# In staging/production we use PostgreSQL via Cloud SQL
module SQLite3Configuration
  private
    def configure_connection
      super

      if @config[:retries]
        retries = self.class.type_cast_config_to_integer(@config[:retries])
        raw_connection.busy_handler do |count|
          (count <= retries).tap { |result| sleep count * 0.001 if result }
        end
      end
    end
end

ActiveSupport.on_load :active_record do
  # Only prepend if SQLite3Adapter is defined (not in production with PostgreSQL)
  if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
    ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend SQLite3Configuration
  end
end
