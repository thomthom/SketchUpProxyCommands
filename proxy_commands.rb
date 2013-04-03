#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'

# Ensure older versions doesn't overwrite newer versions.
unless defined?(CommunityExtensions::ProxyCommands) &&
  CommunityExtensions::ProxyCommands.newer_than?('1.0.0') # <- Version of this file

module CommunityExtensions
  # @example
  #   validation = Proc.new { self.is_mode_active? }
  #   pc = CommunityExtensions::ProxyCommands
  #   pc.register(:move, validation) {
  #     Sketchup.active_model.select_tool(MyCustomMoveTool.new)
  #   }
  #   pc.register(:rotate, validation) {
  #     Sketchup.active_model.select_tool(MyCustomRotateTool.new)
  #   }
  #   pc.register(:scale, validation) {
  #     Sketchup.active_model.select_tool(MyCustomScaleTool.new)
  #   }
  #
  # @since 1.0.0
  module ProxyCommands

    # @since 1.0.0
    PLUGIN = self
    PLUGIN_ID = 'ProxyCommands'.freeze
    PLUGIN_NAME = 'Proxy Commands'.freeze
    PLUGIN_VERSION = '1.0.0'.freeze

    puts "Loading #{self} Version: #{PLUGIN_VERSION}"

    # @since 1.0.0
    unless defined?(ProxyCommand)
      ProxyCommand = Struct.new(:command, :validation_proc)
    end

    @registered ||= {}

    # Used by a load guard to ensure that older versions does not overwrite a
    # newer one. Part of this ProxyCommand API design is that newer versions
    # are required to be compatible with older versions.
    #
    # @param [String] version
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.newer_than?(version)
      this_major, this_minor, this_revision = PLUGIN_VERSION.split('.')
      major, minor, revision = version.split('.')

      major = 0 if major.nil?
      minor = 0 if minor.nil?
      revision = 0 if revision.nil?

      return true if major < this_major
      if this_major == major
        return true if minor < this_minor
      end
      if this_minor == minor
        return true if revision < this_revision
      end
      false
    end
  
    # @param [Symbol] command_id
    # @param [Proc] proc
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.register(command_id, validation, &proc)
      unless Commands.include?(command_id)
        raise ArgumentError, 'Invalid command ID.'
      end
      unless validation.is_a?(Proc)
        raise ArgumentError, '`validation` is not a valid Proc type.'
      end
      unless block_given?
        raise ArgumentError, "No block given."
      end
      @registered[command_id] ||= []
      if @registered[command_id].include?(proc)
        false
      else
        @registered[command_id] << ProxyCommand.new(proc, validation)
        true
      end
    end

    # Debugging method that clears all registered proxy commands.
    #
    # @return [Nil]
    # @since 1.0.0
    def self.clear!
      @registered.clear
      nil
    end

    # Internal method responsible for triggering the registered commands.
    #
    # @param [Symbol] command_id
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.trigger(command_id)
      return false unless @registered[command_id]
      for command in @registered[command_id]
        if command.validation_proc.call
          command.command.call
          return true
        end
      end
      false
    end


    # @since 1.0.0
    module Commands

      @command_ids = Set.new

      # @param [Symbol] command_id
      #
      # @return [Boolean]
      # @since 1.0.0
      def self.include?(command_id)
        @command_ids.include?(command_id)
      end

      # Internal method to create UI::Command objects handling proxy commands.
      #
      # @param [Symbol] command_id
      # @param [String] title
      #
      # @return [UI::Command]
      # @since 1.0.0
      def self.proxy(command_id, title, &default)
        @command_ids.insert(command_id)
        UI::Command.new(title) {
          unless PLUGIN::trigger(command_id)
            default.call
          end
        }
      end

      ##### Edit ###############################################################

      # @since 1.0.0
      def self.select_all
        self.proxy(:select_all, 'Select All') {
          model = Sketchup.active_model
          model.selection.add(model.active_entities.to_a)
        }
      end
      # @since 1.0.0
      def self.select_none
        self.proxy(:select_none, 'Select None') {
          Sketchup.active_model.selection.clear
        }
      end
      # @since 1.0.0
      def self.invert_selection
        self.proxy(:invert_selection, 'Invert Selection') {
          model = Sketchup.active_model
          model.selection.toggle(model.active_entities.to_a)
        }
      end

      ##### Tools ##############################################################

      # @since 1.0.0
      def self.select_tool
        self.proxy(:select_tool, 'Select') {
          Sketchup.send_action('selectSelectionTool:')
        }
      end
      # @since 1.0.0
      def self.erase_tool
        self.proxy(:select_tool, 'Eraser') {
          Sketchup.send_action('selectEraseTool:')
        }
      end
      # @since 1.0.0
      def self.move_tool
        self.proxy(:move_tool, 'Move') {
          Sketchup.send_action('selectMoveTool:')
        }
      end
      # @since 1.0.0
      def self.rotate_tool
        self.proxy(:rotate_tool, 'Rotate') {
          Sketchup.send_action('selectRotateTool:')
        }
      end
      # @since 1.0.0
      def self.scale_tool
        self.proxy(:scale_tool, 'Scale') {
          Sketchup.send_action('selectScaleTool:')
        }
      end
    end # module Commands


    # (!) Need a load guard system!
    unless file_loaded?( __FILE__ )
      root_menu = UI.menu('Plugins').add_submenu(PLUGIN_NAME)

      m = root_menu.add_submenu('Edit')
      m.add_item(Commands.select_all)
      m.add_item(Commands.select_none)
      m.add_item(Commands.invert_selection)

      m = root_menu.add_submenu('Tools')
      m.add_item(Commands.select_tool)
      m.add_item(Commands.erase_tool)
      m.add_separator
      m.add_item(Commands.move_tool)
      m.add_item(Commands.rotate_tool)
      m.add_item(Commands.scale_tool)
    end

  end # module ProxyCommands
end # module CommunityExtensions

end # Version Check

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------