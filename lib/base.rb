require "yaml"
require "psych"

def root_path
  File.dirname(__dir__)
end

def recipe_path
  File.join(root_path, "recipe")
end

def files_path
  File.join(root_path, "template", "files")
end

def eval_file_content(file_path)
  eval File.read(file_path)
end

def recipe(name)
  eval_file_content File.join(recipe_path, "#{name}.rb")
end

def from_files(path)
  File.join(files_path, path)
end

def update_yaml(file_path, data)
  yaml = Psych.load_file(file_path) || {}
  yaml.update(data)
  ast = Psych.parse_stream yaml.to_yaml
  ast.grep(Psych::Nodes::Scalar).each do |node|
    node.plain = true
    node.quoted = false
    node.style  = Psych::Nodes::Scalar::ANY
  end
  File.write(file_path, ast.yaml)
end

# Lifecycle hooks for managing execution order
# Recipes can register callbacks for different phases to ensure proper timing
module LifecycleHooks
  class << self
    def after_generators_callbacks
      @after_generators_callbacks ||= []
    end

    def register_after_generators(&block)
      after_generators_callbacks << block
    end

    def run_after_generators
      after_generators_callbacks.each(&:call)
    end
  end
end

# Register a callback to run after all generators complete
# This ensures gems are fully loaded before initializers that depend on them
#
# Example usage in recipe:
#   after_generators do
#     initializer "my_gem.rb", "MyGem.configure do; end"
#   end
def after_generators(&)
  LifecycleHooks.register_after_generators(&)
end

# Execute all registered after_generators callbacks
# Called from template/api.rb after all generators have finished
def run_after_generators
  LifecycleHooks.run_after_generators
end
