require 'active_record/connection_adapters/abstract_adapter'
require 'active_support/core_ext/kernel/requires'
require 'active_support/core_ext/object/blank'
require 'vertica'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects
    def self.vertica_connection(config) # :nodoc:
      config = config.symbolize_keys
      host     = config[:host]
      port     = config[:port] || 5433
      username = config[:username].to_s if config[:username]
      password = config[:password].to_s if config[:password]
      ssl      = config[:ssl].to_s if config[:ssl]
      if config.key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      # The vertica drivers don't allow the creation of an unconnected object,
      # so just pass a nil connection object for the time being.
      ConnectionAdapters::VerticaAdapter.new(nil, logger, [host, port, database, username, password, ssl, nil], config)
    end
  end

  module ConnectionAdapters
    class TableDefinition 
      def column(name, type, options = {})
        column = self[name] || ColumnDefinition.new(@base, name, type)
        if options[:limit]
          column.limit = options[:limit]
        elsif native[type.to_sym].is_a?(Hash)
          column.limit = native[type.to_sym][:limit]
        end
        column.precision = options[:precision]
        column.scale = options[:scale]
        column.default = options[:default]
        column.null = options[:null]
        column.encoding = options[:encoding]
        @columns << column unless @columns.include? column
        self
      end
    end
    
    class ColumnDefinition
      attr_accessor :encoding
      
      def to_sql
        column_sql = "#{base.quote_column_name(name)} #{sql_type}"
        column_options = {}
        column_options[:encoding] = encoding
        column_options[:null] = null unless null.nil?
        column_options[:default] = default unless default.nil?
        add_column_options!(column_sql, column_options) unless type.to_sym == :primary_key
        column_sql
      end
    end
    
    # Vertica-specific extensions to column definitions in a table.
    class VerticaColumn < Column #:nodoc:
      # Instantiates a new Vertica column definition in a table.
      def initialize(name, default, sql_type = nil, null = true)
        super(name, self.class.extract_value_from_default(default), sql_type, null)
      end

      # :stopdoc:
      class << self
        attr_accessor :money_precision
      end
      # :startdoc:

      private
        def extract_limit(sql_type)
          case sql_type
          when /^integer/i;    8
          else super
          end
        end

        # Extracts the scale from Vertica-specific data types.
        def extract_scale(sql_type)
          # Money type has a fixed scale of 2.
          sql_type =~ /^money/ ? 2 : super
        end

        # Extracts the precision from Vertica-specific data types.
        def extract_precision(sql_type)
          if sql_type == 'money'
            self.class.money_precision
          else
            super
          end
        end

        # Maps Vertica-specific data types to logical Rails types.
        def simplified_type(field_type)
          case field_type
            # Numeric and monetary types
            when /^(?:real|double precision)$/
              :float
            # Monetary types
            when 'money'
              :decimal
            # Character types
            when /^(?:character varchar|varying|bpchar)(?:\(\d+\))?$/
              :string
            # Binary data types
            when 'bytea'
              :binary
            when 'binary'
              :binary
            # Date/time types
            when /^timestamp with(?:out)? time zone$/
              :datetime
            when 'interval'
              :string
            # Geometric types
            when /^(?:point|line|lseg|box|"?path"?|polygon|circle)$/
              :string
            # Network address types
            when /^(?:cidr|inet|macaddr)$/
              :string
            # Bit strings
            when /^bit(?: varying)?(?:\(\d+\))?$/
              :string
            # XML type
            when 'xml'
              :xml
            # Arrays
            when /^\D+\[\]$/
              :string
            # Object identifier types
            when 'oid'
              :integer
            # UUID type
            when 'uuid'
              :string
            # Small and big integer types
            when /^(?:small|big)int$/
              :integer
            # Pass through all types that are not specific to Vertica.
            else
              super
          end
        end

        # Extracts the value from a Vertica column default definition.
        def self.extract_value_from_default(default)
          case default
            # Numeric types
            when /\A\(?(-?\d+(\.\d*)?\)?)\z/
              $1
            # Character types
            when /\A'(.*)'::(?:character varchar|varying|bpchar|text)\z/m
              $1
            # Character types (8.1 formatting)
            when /\AE'(.*)'::(?:character varchar|varying|bpchar|text)\z/m
              $1.gsub(/\\(\d\d\d)/) { $1.oct.chr }
            # Binary data types
            when /\A'(.*)'::bytea\z/m
              $1
            # Date/time types
            when /\A'(.+)'::(?:time(?:stamp)? with(?:out)? time zone|date)\z/
              $1
            when /\A'(.*)'::interval\z/
              $1
            # Boolean type
            when 'true'
              true
            when 'false'
              false
            # Geometric types
            when /\A'(.*)'::(?:point|line|lseg|box|"?path"?|polygon|circle)\z/
              $1
            # Network address types
            when /\A'(.*)'::(?:cidr|inet|macaddr)\z/
              $1
            # Bit string types
            when /\AB'(.*)'::"?bit(?: varying)?"?\z/
              $1
            # XML type
            when /\A'(.*)'::xml\z/m
              $1
            # Arrays
            when /\A'(.*)'::"?\D+"?\[\]\z/
              $1
            # Object identifier types
            when /\A-?\d+\z/
              $1
            else
              # Anything else is blank, some user type, or some function
              # and we can't know the value of that, so return nil.
              nil
          end
        end
    end

    # The Vertica adapter works both with the native C (http://ruby.scripting.ca/postgres/) and the pure
    # Ruby (available both as gem and from http://rubyforge.org/frs/?group_id=234&release_id=1944) drivers.
    #
    # Options:
    #
    # * <tt>:host</tt> - Defaults to "localhost".
    # * <tt>:port</tt> - Defaults to 5432.
    # * <tt>:username</tt> - Defaults to nothing.
    # * <tt>:password</tt> - Defaults to nothing.
    # * <tt>:database</tt> - The name of the database. No default, must be provided.
    # * <tt>:schema_search_path</tt> - An optional schema search path for the connection given
    #   as a string of comma-separated schema names.  This is backward-compatible with the <tt>:schema_order</tt> option.
    # * <tt>:encoding</tt> - An optional client encoding that is used in a <tt>SET client_encoding TO
    #   <encoding></tt> call on the connection.
    # * <tt>:allow_concurrency</tt> - If true, use async query methods so Ruby threads don't deadlock;
    #   otherwise, use blocking query methods.
    class VerticaAdapter < AbstractAdapter
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def xml(*args)
          options = args.extract_options!
          column(args[0], 'xml', options)
        end
      end

      ADAPTER_NAME = 'Vertica'

      NATIVE_DATABASE_TYPES = {
        :primary_key => "PRIMARY KEY IDENTITY(1,1)",
        :string      => { :name => "character varying", :limit => 255 },
        :text        => { :name => "text" },
        :integer     => { :name => "integer" },
        :float       => { :name => "float" },
        :decimal     => { :name => "decimal" },
        :datetime    => { :name => "timestamp" },
        :timestamp   => { :name => "timestamp" },
        :time        => { :name => "time" },
        :date        => { :name => "date" },
        :binary      => { :name => "bytea" },
        :boolean     => { :name => "boolean" },
        :xml         => { :name => "xml" }
      }

      # Returns 'Vertica' as adapter name for identification purposes.
      def adapter_name
        ADAPTER_NAME
      end

      # Initializes and connects a Vertica adapter.
      def initialize(connection, logger, connection_parameters, config)
        super(connection, logger)
        @connection_parameters, @config = connection_parameters, config

        # @local_tz is initialized as nil to avoid warnings when connect tries to use it
        @local_tz = nil
        @table_alias_length = nil
        @vertica_version = nil

        connect
        @local_tz = execute('SHOW TIME ZONE')[0][0]
      end

      # Is this connection alive and ready for queries?
      def active?
        @connection.query 'SELECT 1'
        true
      rescue
        false
      end

      # Close then reopen the connection.
      def reconnect!
        disconnect!
        connect
      end

      # Close the connection.
      def disconnect!
        @connection.close rescue nil
      end

      def native_database_types #:nodoc:
        NATIVE_DATABASE_TYPES
      end

      # Does Vertica support migrations?
      def supports_migrations?
        true
      end

      # Does Vertica support finding primary key on non-Active Record tables?
      def supports_primary_key? #:nodoc:
        true
      end

      # Enable standard-conforming strings if available.
      def set_standard_conforming_strings
        execute('SET standard_conforming_strings TO ON') rescue nil
      end

      def supports_insert_with_returning?
        true
      end

      def supports_ddl_transactions?
        true
      end

      def supports_savepoints?
        true
      end

      # Returns the configured supported identifier length supported by Vertica,
      # or report the default of 63 on Vertica 7.x.
      def table_alias_length
        @table_alias_length ||= 63
      end

      # QUOTING ==================================================

      # Quotes strings for use in SQL input.
      def quote_string(s) #:nodoc:
        @connection.escape(s)
      end

      # Checks the following cases:
      #
      # - table_name
      # - "table.name"
      # - schema_name.table_name
      # - schema_name."table.name"
      # - "schema.name".table_name
      # - "schema.name"."table.name"
      def quote_table_name(name)
        schema, name_part = extract_vertica_identifier_from_name(name.to_s)

        unless name_part
          quote_column_name(schema)
        else
          table_name, name_part = extract_vertica_identifier_from_name(name_part)
          "#{quote_column_name(schema)}.#{quote_column_name(table_name)}"
        end
      end

      # Quotes column names for use in SQL queries.
      def quote_column_name(name) #:nodoc:
        "\"#{name}\""
        #query("SELECT QUOTE_IDENT('#{name}')")[0][0]
      end

      # Quote date/time values for use in SQL input. Includes microseconds
      # if the value is a Time responding to usec.
      def quoted_date(value) #:nodoc:
        if value.acts_like?(:time) && value.respond_to?(:usec)
          "#{super}.#{sprintf("%06d", value.usec)}"
        else
          super
        end
      end

      # DATABASE STATEMENTS ======================================

      # Executes a SELECT query and returns an array of rows. Each row is an
      # array of field values.
      def select_rows(sql, name = nil)
        select_raw(sql, name).last
      end

      # Executes an INSERT query and returns the new record's ID
      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        # Extract the table from the insert sql. Yuck.
        table = sql.split(" ", 4)[2].gsub('"', '')

        # Otherwise, insert then grab last_insert_id.
        if insert_id = super
          insert_id
        else
          # If neither pk nor sequence name is given, look them up.
          unless pk || sequence_name
            pk, sequence_name = *pk_and_sequence_for(table)
          end

          # If a pk is given, fallback to default sequence name.
          # Don't fetch last insert id for a table without a pk.
          if pk && sequence_name ||= default_sequence_name(table, pk)
            last_insert_id(table, sequence_name)
          end
        end
      end
      alias :create :insert

      # Queries the database and returns the results in an Array-like object
      def query(sql, name = nil) #:nodoc:
        log(sql, name) do
          @connection.execute(sql).rows
        end
      end

      # Executes an SQL statement, returning a result object on success
      def execute(sql, name = nil, &block)
        log(sql, name) do
          @connection.execute(sql, &block)
        end
      end

      # Executes an UPDATE query and returns the number of affected tuples.
      def update_sql(sql, name = nil)
        result = super
        result.length == 0 ? 0 : result.rows[0][0]
      end

      # Begins a transaction.
      def begin_db_transaction
        # noop in vertica
      end

      # Commits a transaction.
      def commit_db_transaction
        execute "COMMIT"
      end

      # Aborts a transaction.
      def rollback_db_transaction
        execute "ROLLBACK"
      end

      def create_savepoint
        execute("SAVEPOINT #{current_savepoint_name}")
      end

      def rollback_to_savepoint
        execute("ROLLBACK TO SAVEPOINT #{current_savepoint_name}")
      end

      def release_savepoint
        execute("RELEASE SAVEPOINT #{current_savepoint_name}")
      end

      # SCHEMA STATEMENTS ========================================

      def recreate_database(name) #:nodoc:
        drop_database(name)
        create_database(name)
      end

      # Create a new Vertica database.  Options include <tt>:owner</tt>, <tt>:template</tt>,
      # <tt>:encoding</tt>, <tt>:tablespace</tt>, and <tt>:connection_limit</tt> (note that MySQL uses
      # <tt>:charset</tt> while Vertica uses <tt>:encoding</tt>).
      #
      # Example:
      #   create_database config[:database], config
      #   create_database 'foo_development', :encoding => 'unicode'
      def create_database(name, options = {})
        options = options.reverse_merge(:encoding => "utf8")

        option_string = options.symbolize_keys.sum do |key, value|
          case key
          when :owner
            " OWNER = \"#{value}\""
          when :template
            " TEMPLATE = \"#{value}\""
          when :encoding
            " ENCODING = '#{value}'"
          when :tablespace
            " TABLESPACE = \"#{value}\""
          when :connection_limit
            " CONNECTION LIMIT = #{value}"
          else
            ""
          end
        end

        execute "CREATE DATABASE #{quote_table_name(name)}#{option_string}"
      end

      # Drops a Vertica database
      #
      # Example:
      #   drop_database 'matt_development'
      def drop_database(name) #:nodoc:
        execute "DROP DATABASE IF EXISTS #{quote_table_name(name)}"
      end
      
      def add_index(table_name, column_name, options = {})
        #noop
      end
      
      def remove_index(table_name, options = {})
        #noop
      end
      
      def rename_index(table_name, old_name, new_name)
        #noop
      end

      # Returns the list of all tables in the schema search path or a specified schema.
      def tables(name = nil)
        query(<<-SQL, name).map { |row| row[0] }
          SELECT table_name
          FROM v_catalog.tables
          WHERE table_schema = 'public'
        SQL
      end

      def table_exists?(name)
        name          = name.to_s
        schema, table = name.split('.', 2)

        unless table # A table was provided without a schema
          table  = schema
          schema = nil
        end

        if name =~ /^"/ # Handle quoted table names
          table  = name
          schema = nil
        end

        query(<<-SQL).first[0].to_i > 0
          SELECT COUNT(*)
          FROM v_catalog.tables
          WHERE table_name = '#{table.gsub(/(^"|"$)/,'')}'
        SQL
      end

      # Returns the list of all column definitions for a table.
      def columns(table_name, name = nil)
        # Limit, precision, and scale are all handled by the superclass.
        column_definitions(table_name).collect do |name, type, default, notnull|
          VerticaColumn.new(name, default, type, notnull == 'false')
        end
      end
      
      def add_column_options!(sql, options) #:nodoc:
        super(sql, options)
        case options[:encoding]
        when :rle then sql << " ENCODING RLE"
        when :deltaval then sql << " ENCODING DELTAVAL"  
        when :block_dict then sql << " ENCODING BLOCK_DICT"
        when :block_dict_comp then sql << " ENCODING BLOCKDICT_COMP"
        when :delta_range_comp then sql << " ENCODING DELTARANGE_COMP"
        when :common_delta_comp then sql << " ENCODING COMMONDELTA_COMP"
        else raise "Unknown encoding type #{options[:encoding].to_s}"
        end unless options[:encoding].nil?
      end

      # Returns the current database name.
      def current_database
        query('select current_database()')[0][0]
      end

      # Returns the current database encoding format.
      def encoding
        # noop?
      end

      # Sets the schema search path to a string of comma-separated schema names.
      # Names beginning with $ have to be quoted (e.g. $user => '$user').
      # See: http://www.vertica.org/docs/current/static/ddl-schemas.html
      #
      # This should be not be called manually but set in database.yml.
      def schema_search_path=(schema_csv)
        if schema_csv
          execute "SET search_path TO #{schema_csv}"
          @schema_search_path = schema_csv
        end
      end

      # Returns the active schema search path.
      def schema_search_path
        @schema_search_path ||= query('SHOW search_path')[0][0]
      end

      # Returns the sequence name for a table's primary key or some other specified key.
      def default_sequence_name(table_name, pk = nil) #:nodoc:
        default_pk, default_seq = pk_and_sequence_for(table_name)
        default_seq || "#{table_name}_#{pk || default_pk || 'id'}_seq"
      end

      # Resets the sequence of a table's primary key to the maximum value.
      def reset_pk_sequence!(table, pk = nil, sequence = nil) #:nodoc:
        unless pk and sequence
          default_pk, default_sequence = pk_and_sequence_for(table)
          pk ||= default_pk
          sequence ||= default_sequence
        end
        if pk
          if sequence
            quoted_sequence = quote_column_name(sequence)

            select_value <<-end_sql, 'Reset sequence'
              SELECT setval('#{quoted_sequence}', (SELECT COALESCE(MAX(#{quote_column_name pk})+(SELECT increment_by FROM #{quoted_sequence}), (SELECT min_value FROM #{quoted_sequence})) FROM #{quote_table_name(table)}), false)
            end_sql
          else
            @logger.warn "#{table} has primary key #{pk} with no default sequence" if @logger
          end
        end
      end

      # Returns a table's primary key and belonging sequence.
      def pk_and_sequence_for(table) #:nodoc:
        result = query(<<-end_sql, 'PK and serial sequence')[0]
          SELECT    columns.column_name, columns.column_default 
          FROM      primary_keys 
          LEFT JOIN columns 
            USING(table_name, column_name)
          WHERE     primary_keys.table_name = '#{table_name.gsub(/(^"|"$)/,'')}'
        end_sql
        
        if result.length == 0
          return nil
        elsif result[0][1].nil?
          return nil
        else
          default_value = result[0][1]
          seq_name = default_value.match(/\(\'(\w+)\'\)/).to_a.last
          return [result[0][0], seq_name]
        end
      rescue
        nil
      end

      # Returns just a table's primary key
      def primary_key(table)
        pk_and_sequence = pk_and_sequence_for(table)
        pk_and_sequence && pk_and_sequence.first
      end

      # Renames a table.
      def rename_table(name, new_name)
        execute "ALTER TABLE #{quote_table_name(name)} RENAME TO #{quote_table_name(new_name)}"
      end

      # Adds a new column to the named table.
      # See TableDefinition#column for details of the options you can use.
      def add_column(table_name, column_name, type, options = {})
        default = options[:default]
        notnull = options[:null] == false
        
        # Add the column.
        execute("ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}")

        change_column_default(table_name, column_name, default) if options_include_default?(options)
        change_column_null(table_name, column_name, false, default) if notnull
      end

      # Changes the column of a table.
      def change_column(table_name, column_name, type, options = {})
        quoted_table_name = quote_table_name(table_name)

        begin
          execute "ALTER TABLE #{quoted_table_name} ALTER COLUMN #{quote_column_name(column_name)} TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        rescue ActiveRecord::StatementInvalid => e
          begin
            begin_db_transaction
            tmp_column_name = "#{column_name}_ar_tmp"
            add_column(table_name, tmp_column_name, type, options)
            execute "UPDATE #{quoted_table_name} SET #{quote_column_name(tmp_column_name)} = CAST(#{quote_column_name(column_name)} AS #{type_to_sql(type, options[:limit], options[:precision], options[:scale])})"
            remove_column(table_name, column_name)
            rename_column(table_name, tmp_column_name, column_name)
            commit_db_transaction
          rescue
            rollback_db_transaction
          end
        end

        change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
        change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
      end

      # Changes the default value of a table column.
      def change_column_default(table_name, column_name, default)
        execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}"
      end

      def change_column_null(table_name, column_name, null, default = nil)
        unless null || default.nil?
          execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end
        execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL")
      end

      # Renames a column in a table.
      def rename_column(table_name, column_name, new_column_name)
        execute "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
      end

      def remove_index!(table_name, index_name) #:nodoc:
        # no-op in vertica 
      end

      def index_name_length
        63
      end

      # Maps logical Rails types to Vertica-specific data types.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil)
        return super unless type.to_s == 'integer'
        return 'integer' unless limit

        case limit
          when 1..8; 'integer'
          else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
        end
      end

      # Returns a SELECT DISTINCT clause for a given set of columns and a given ORDER BY clause.
      #
      # Vertica requires the ORDER BY columns in the select list for distinct queries, and
      # requires that the ORDER BY include the distinct column.
      #
      #   distinct("posts.id", "posts.created_at desc")
      def distinct(columns, order_by) #:nodoc:
        return "DISTINCT #{columns}" if order_by.blank?

        # Construct a clean list of column names from the ORDER BY clause, removing
        # any ASC/DESC modifiers
        order_columns = order_by.split(',').collect { |s| s.split.first }
        order_columns.delete_if { |c| c.blank? }
        order_columns = order_columns.zip((0...order_columns.size).to_a).map { |s,i| "#{s} AS alias_#{i}" }

        # Return a DISTINCT ON() clause that's distinct on the columns we want but includes
        # all the required columns for the ORDER BY to work properly.
        sql = "DISTINCT ON (#{columns}) #{columns}, "
        sql << order_columns * ', '
      end

      protected
        def translate_exception(exception, message)
          case exception.message
          when /duplicate key value violates unique constraint/
            RecordNotUnique.new(message, exception)
          when /violates foreign key constraint/
            InvalidForeignKey.new(message, exception)
          else
            super
          end
        end

      private
        # The internal Vertica identifier of the money data type.
        MONEY_COLUMN_TYPE_OID = 16 #:nodoc:
        # The internal Vertica identifier of the BYTEA data type.
        BYTEA_COLUMN_TYPE_OID = 17 #:nodoc:

        # Connects to a Vertica server and sets up the adapter depending on the
        # connected server's characteristics.
        def connect
          @connection = Vertica::Connection.new(*@connection_parameters)
          Vertica.translate_results = false if Vertica.respond_to?(:translate_results=)

          # Ignore async_exec and async_query when using postgres-pr.
          @async = @config[:allow_concurrency] && @connection.respond_to?(:async_exec)

          # All vertica money columns have precision 18
          VerticaColumn.money_precision = 18

          configure_connection
        end

        # Configures the encoding, verbosity, schema search path, and time zone of the connection.
        # This is called by #connect and should not be called manually.
        def configure_connection
          if @config[:encoding]
            if @connection.respond_to?(:set_client_encoding)
              @connection.set_client_encoding(@config[:encoding])
            else
              execute("SET client_encoding TO '#{@config[:encoding]}'")
            end
          end
          self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]

          # Use standard-conforming strings if available so we don't have to do the E'...' dance.
          set_standard_conforming_strings

          # If using Active Record's time zone support configure the connection to return
          # TIMESTAMP WITH ZONE types in UTC.
          if ActiveRecord::Base.default_timezone == :utc
            execute("SET time zone 'UTC'")
          elsif @local_tz
            execute("SET time zone '#{@local_tz}'")
          end
        end

        # Returns the current ID of a table's sequence.
        def last_insert_id(table, sequence_name) #:nodoc:
          Integer(select_value("SELECT currval('#{sequence_name}')"))
        end

        # Executes a SELECT query and returns the results, performing any data type
        # conversions that are required to be performed here instead of in VerticaColumn.
        def select(sql, name = nil)
          fields, rows = select_raw(sql, name)
          rows.map do |row|
            Hash[*fields.zip(row).flatten]
          end
        end

        def select_raw(sql, name = nil)
          res = execute(sql, name)
          return res.columns.collect{|c| c.name}, res.rows
        end

        # Returns the list of a table's column names, data types, and default values.
        #
        # Query implementation notes:
        #  - format_type includes the column size constraint, e.g. varchar(50)
        def column_definitions(table_name) #:nodoc:
          query <<-end_sql
            SELECT column_name, data_type, column_default, is_nullable
            FROM   v_catalog.columns
            WHERE  table_name = '#{table_name.gsub(/(^"|"$)/,'')}'
          end_sql
        end

        def extract_vertica_identifier_from_name(name)
          match_data = name[0,1] == '"' ? name.match(/\"([^\"]+)\"/) : name.match(/([^\.]+)/)

          if match_data
            rest = name[match_data[0].length..-1]
            rest = rest[1..-1] if rest[0,1] == "."
            [match_data[1], (rest.length > 0 ? rest : nil)]
          end
        end

      def table_definition
        TableDefinition.new(self)
      end
    end
  end
end


