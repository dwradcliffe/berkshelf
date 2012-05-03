module Remy
  class Shelf
    attr_accessor :cookbooks

    def initialize
      @cookbooks = []
    end
    
    def shelve_cookbook(name, version_constraint=nil)
      @cookbooks << Cookbook.new(name, version_constraint)
    end

    def resolve_dependencies
      graph = DepSelector::DependencyGraph.new
      shelf = MetaCookbook.new('remy_shelf', @cookbooks) # all cookbooks in the
                                             # Cheffile are dependencies
                                             # of the shelf

      self.class.populate_graph graph, shelf

      selector = DepSelector::Selector.new(graph)
      solution = selector.find_solution([DepSelector::SolutionConstraint.new(graph.package('remy_shelf'))])
      solution.delete 'remy_shelf'
      solution
    end

    def download_cookbooks
      resolve_dependencies.each_pair do |cookbook_name, version|
        FileUtils.mkdir 'cookbooks' unless File.exists? 'cookbooks'
        Cookbook.new(cookbook_name, version.to_s).unpack(File.expand_path('cookbooks'))
      end
    end

    class << self
      def populate_graph(graph, cookbook)
        package = graph.package cookbook.name
        cookbook.versions.each { |v| package.add_version(v) }

        cookbook.dependencies.each do |dependency|
          graph = populate_graph(graph, dependency)
          dep = graph.package(dependency.name)
          version = package.versions.select { |v| v.version == cookbook.latest_constrained_version }.first
          version.dependencies << DepSelector::Dependency.new(dep, dependency.version_constraint)
        end

        graph
      end
    end
  end
end