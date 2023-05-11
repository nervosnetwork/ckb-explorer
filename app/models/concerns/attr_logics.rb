module AttrLogics
  extend ActiveSupport::Concern
  included do
    class_attribute :attr_definitions
    self.attr_definitions = {}
  end

  class_methods do
    def define_logic(attr_name, &block)
      attr_definitions[attr_name] = block
      define_method "reset_#{attr_name}" do
        reset attr_name
      end

      define_method "fill_#{attr_name}" do
        fill attr_name
      end
    end
  end

  def reset(*attr_names)
    attr_names.flatten.each do |a|
      reset_one a
    end
  end

  def reset!(*attr_names)
    reset *attr_names
    save!
  end

  def reset_all
    reset attr_definitions.keys
  end

  def reset_all!
    reset_all
    save!
  end

  def reset_one(attr_name)
    raise "undefined attribute '#{attr_name}' calculation logic" unless attr_definitions[attr_name]

    self[attr_name] = instance_eval(&attr_definitions[attr_name])
  end

  def reset_one!(attr_name)
    reset_one(attr_name)
    save!
  end

  # fill will not modify the value if it is already set
  def fill(*attr_names)
    attr_names.flatten.each do |a|
      fill_one a
    end
  end

  def fill!(*attr_names)
    fill *attr_names
    save!
  end

  def fill_all
    fill attr_definitions.keys
  end

  def fill_all!
    fill_all
    save!
  end

  def fill_one(attr_name)
    raise "undefined attribute '#{attr_name}' calculation logic" unless attr_definitions[attr_name]

    self[attr_name] ||= instance_eval(&attr_definitions[attr_name])
  end

  def fill_one!(attr_name)
    fill_one(attr_name)
    save!
  end
end
