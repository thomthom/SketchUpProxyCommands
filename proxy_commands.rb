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

      @command_ids ||= Set.new

      # CommunityExtensions::ProxyCommands::Commands.command_ids
      #
      # @return [Array]
      # @since 1.0.0
      def self.command_ids
        @command_ids.to_a
      end

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
      def self.undo
        self.proxy(:undo, 'Undo') {
          Sketchup.send_action('editUndo:')
        }
      end
      # @since 1.0.0
      def self.redo
        self.proxy(:redo, 'Redo') {
          Sketchup.send_action('editRedo:')
        }
      end

      # @since 1.0.0
      def self.cut
        self.proxy(:cut, 'Cut') {
          Sketchup.send_action('cut:')
        }
      end
      # @since 1.0.0
      def self.copy
        self.proxy(:copy, 'Copy') {
          Sketchup.send_action('copy:')
        }
      end
      # @since 1.0.0
      def self.paste
        self.proxy(:paste, 'Paste') {
          Sketchup.send_action('paste:')
        }
      end
      # @since 1.0.0
      def self.delete
        self.proxy(:delete, 'Delete') {
          Sketchup.send_action('editDelete:')
        }
      end

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

      def self.hide
        self.proxy(:hide, 'Hide') {
          Sketchup.send_action('editHide:')
        }
      end
      def self.unhide
        self.proxy(:unhide, 'Unhide Selected') {
          Sketchup.send_action('editUnhide:')
        }
      end

      ##### Draw ###############################################################

      # @since 1.0.0
      def self.line_tool
        self.proxy(:line_tool, 'Line') {
          Sketchup.send_action('selectLineTool:')
        }
      end
      def self.arc_tool
        self.proxy(:arc_tool, 'Arc') {
          Sketchup.send_action('selectArcTool:')
        }
      end
      def self.freehand_tool
        self.proxy(:freehand_tool, 'Freehand') {
          Sketchup.send_action('selectFreehandTool:')
        }
      end

      def self.rectangle_tool
        self.proxy(:rectangle_tool, 'Rectangle') {
          Sketchup.send_action('selectRectangleTool:')
        }
      end
      def self.circle_tool
        self.proxy(:circle_tool, 'Circle') {
          Sketchup.send_action('selectCircleTool:')
        }
      end
      def self.polygon_tool
        self.proxy(:polygon_tool, 'Polygon') {
          Sketchup.send_action('selectPolygonTool:')
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
        self.proxy(:eraser_tool, 'Eraser') {
          Sketchup.send_action('selectEraseTool:')
        }
      end
      # @since 1.0.0
      def self.paint_tool
        self.proxy(:paint_tool, 'Paint Bucket') {
          Sketchup.send_action('selectPaintTool:')
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

      # @since 1.0.0
      def self.pushpull_tool
        self.proxy(:pushpull_tool, 'Push/Pull') {
          Sketchup.send_action('selectPushPullTool:')
        }
      end
      # @since 1.0.0
      def self.followme_tool
        self.proxy(:followme_tool, 'Follow Me') {
          Sketchup.send_action('selectExtrudeTool:')
        }
      end
      # @since 1.0.0
      def self.offset_tool
        self.proxy(:offset_tool, 'Offset') {
          Sketchup.send_action('selectOffsetTool:')
        }
      end

      # @since 1.0.0
      def self.tapemeasure_tool
        self.proxy(:tapemeasure_tool, 'Tape Measure') {
          Sketchup.send_action('selectMeasureTool:')
        }
      end
      # @since 1.0.0
      def self.protractor_tool
        self.proxy(:protractor_tool, 'Protractor') {
          Sketchup.send_action('selectProtractorTool:')
        }
      end
      # @since 1.0.0
      def self.axes_tool
        self.proxy(:axes_tool, 'Axes') {
          Sketchup.send_action('selectAxisTool:')
        }
      end

      # @since 1.0.0
      def self.dimensions_tool
        self.proxy(:dimensions_tool, 'Dimensions') {
          Sketchup.send_action('selectDimensionTool:')
        }
      end
      # @since 1.0.0
      def self.text_tool
        self.proxy(:text_tool, 'Text') {
          Sketchup.send_action('selectTextTool:')
        }
      end
      # @since 1.0.0
      def self.text3d_tool
        self.proxy(:text3d_tool, '3D Text') {
          Sketchup.send_action('select3dTextTool:')
        }
      end

      # @since 1.0.0
      def self.sectionplane_tool
        self.proxy(:sectionplane_tool, 'Section Plane') {
          Sketchup.send_action('selectSectionPlaneTool:')
        }
      end
    end # module Commands


    # Internal method ensuring duplicate top level menus are nor created.
    #
    # @param [Sketchup::Menu] menu
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.get_top_menu(name)
      # Ensure there is only one tool menu.
      @root_menu ||= UI.menu('Plugins').add_submenu(PLUGIN_NAME)
      # Ensure there is only one menu per top level.
      @top_menus ||= {}
      @top_menus[name] ||= @root_menu.add_submenu(name)
      # Reset the internal list of last menu items. This indicate a new version
      # is being loaded.
      menu = @top_menus[name]
      @last_menu ||= {}
      @last_menu[menu] = []
      menu
    end

    # Internal method ensuring duplicate menu items are not created.
    #
    # @param [Sketchup::Menu] parent_menu
    # @param [Symbol] command_id
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.add_menu(parent_menu, command_id)
      puts "add_menu(#{parent_menu}, #{command_id})"
      #TT.debug "add_menu(#{parent_menu}, #{command_id})"
      @menus ||= {}
      @menus[parent_menu] ||= []
      @last_menu ||= {}
      if @menus[parent_menu].include?(command_id)
        @last_menu[parent_menu] << command_id
        return false
      end
      #return false if @menus[parent_menu].include?(command_id)
      #return false if Commands.include?(command_id)
      puts "> Adding..."
      index = self.get_menu_index(parent_menu, command_id)
      puts "> Index: #{index}"
      #TT.debug "> Index: #{index}"
      p parent_menu.add_item(Commands.send(command_id), index)
      @menus[parent_menu].insert(index, command_id)
      @last_menu[parent_menu] << command_id
      true
    end

    # Internal method ensuring duplicate menu separators are not created.
    #
    # @param [Sketchup::Menu] parent_menu
    # @param [Symbol] command_id
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.add_separator(parent_menu)
      puts "add_separator(#{parent_menu})"
      @menus ||= {}
      @menus[parent_menu] ||= []
      @last_menu ||= {}
      previous_menu = @last_menu[parent_menu].last
      if @menus[parent_menu].last == :separator
        @last_menu[parent_menu] << :separator
        return false 
      end
      puts '> Previous Menu Index:'
      p @menus[parent_menu].index(previous_menu)
      p @menus[parent_menu].length
      previous_index = @menus[parent_menu].index(previous_menu)
      previous_max_index = @menus[parent_menu].length - 1
      unless previous_index == previous_max_index
        puts '> Previous Menu was inserted.'
        @last_menu[parent_menu] << :separator
        return false
      end
      puts "> Adding..."
      # (!) Prevent separator from being created if last inserted menu is at the
      #     end of the menu list. Currently it is impossible to control the
      #     insert index of separators.
      parent_menu.add_separator
      @menus[parent_menu] << :separator
      @last_menu[parent_menu] << :separator
      true
    end

    # load 'proxy_commands.rb.x'
    def self.get_menu_index(parent_menu, command_id)
      puts "get_menu_index(#{parent_menu}, #{command_id})"
      menu_list = @menus[parent_menu]
      p menu_list
      previous_menu = @last_menu[parent_menu].last
      puts "> Previous menu: #{previous_menu.inspect}"
      previous_was_separator = previous_menu == :separator
      if previous_was_separator
        puts '> Last was separator - find the menu:'
        previous_menu = @last_menu[parent_menu][-2]
        puts "> Previous menu: #{previous_menu.inspect}"
      end
      previous_index = menu_list.index(previous_menu)
      puts "> Previous index: #{previous_index.inspect}"
      if previous_index
        previous_index += 1
        previous_index += 1 if previous_was_separator
        puts "> Returning index: #{previous_index.inspect}"
        previous_index
      else
        puts "> Returning index: #{previous_index.inspect}"
        @menus[parent_menu].length
      end
    end


    # (!) Need a load guard system!
    #     If a newer file is loaded then it will create a new set of menus.
    #     A system to prevent duplicates and allow newer versions to add new
    #     menu items is needed.
    #unless file_loaded?( __FILE__ )
      m = self.get_top_menu('Edit')
      self.add_menu(m, :undo)
      self.add_menu(m, :redo)
      self.add_separator(m)
      self.add_menu(m, :cut)
      self.add_menu(m, :copy) if file_loaded?( __FILE__ )
      self.add_menu(m, :paste)
      # (!) Missing: Paste In Place
      self.add_menu(m, :delete)
      self.add_separator(m)
      self.add_menu(m, :select_all) if file_loaded?( __FILE__ )
      self.add_menu(m, :select_none) if file_loaded?( __FILE__ )
      self.add_menu(m, :invert_selection)
      self.add_separator(m)
      self.add_menu(m, :hide)
      # (!) Missing: Unhide Last
      self.add_menu(m, :unhide)
      # (!) Missing: Unhide All

      m = self.get_top_menu('Draw')
      self.add_menu(m, :line_tool)
      self.add_menu(m, :arc_tool)
      self.add_menu(m, :freehand_tool)
      self.add_separator(m)
      self.add_menu(m, :rectangle_tool)
      self.add_menu(m, :circle_tool)
      self.add_menu(m, :polygon_tool)

      m = self.get_top_menu('Tools')
      self.add_menu(m, :select_tool)
      self.add_menu(m, :erase_tool)
      self.add_menu(m, :paint_tool)
      self.add_separator(m)
      self.add_menu(m, :move_tool)
      self.add_menu(m, :rotate_tool)
      self.add_menu(m, :scale_tool)
      self.add_separator(m)
      self.add_menu(m, :pushpull_tool)
      self.add_menu(m, :followme_tool)
      self.add_menu(m, :offset_tool)
      self.add_separator(m)
      self.add_menu(m, :tapemeasure_tool)
      self.add_menu(m, :protractor_tool)
      self.add_menu(m, :axes_tool)
      self.add_separator(m)
      self.add_menu(m, :dimensions_tool)
      self.add_menu(m, :text_tool)
      self.add_menu(m, :text3d_tool)
      self.add_separator(m)
      self.add_menu(m, :sectionplane_tool)
    #end

  end # module ProxyCommands
end # module CommunityExtensions

end # Version Check

#-------------------------------------------------------------------------------

#file_loaded( __FILE__ )

#-------------------------------------------------------------------------------

puts '======================================'

unless file_loaded?( __FILE__ )
  file_loaded( __FILE__ )
  load __FILE__
end