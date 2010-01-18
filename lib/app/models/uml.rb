require 'set'

module UML
  #usage: UML.print_uml or with options: UML.print_uml(:all, : detailed) or MyOpenObjectResource.print_uml or UML.print_uml([list_of_classes], :all, :detailed)

  def self.included(base) base.extend(ClassMethods) end

  def print_uml(*options)
    UML.print_uml(@config[:models] && @all_loaded_models.select {|model| @config[:models].index(model.openerp_model)} || @all_loaded_models, options)
  end

  module ClassMethods
    def print_uml(*options)
      UML.print_uml([self], options) if self.is_a?(OpenObjectResource)
    end
  end

  def self.display_fields(clazz)
    s = ""
    clazz.reload_fields_definition if clazz.fields.empty?
    clazz.fields.sort {|a,b| a[1].ttype <=> b[1].ttype}.each {|i| s << "+ #{i[1].ttype} : #{i[0]}\\l\\n"}
    s
  end

  def self.print_uml(classes, *options)
    options = options[0] if options[0].is_a?(Array)
    local = (options.index(:all) == nil)
    detailed = (options.index(:detailed) != nil) || local && (options.index(:nodetail) == nil)

    enabled_targets = classes[0].ooor.config[:models] #defines the scope of the UML for option local
    m2o_edges = {}
    o2m_edges = {}
    m2m_edges = {}
    #instead of diplaying several relations of the same kind between two nodes which would bloat the graph,
    #we track them all and factor them on a common multiline edge label:
    connex_classes = UML.collect_edges(false, local, classes, enabled_targets, m2o_edges, o2m_edges, m2m_edges)
    #back links from connex classes:
    connex_classes += UML.collect_edges(true, local, connex_classes - classes, classes, m2o_edges, o2m_edges, m2m_edges)

    File.open('uml.dot', 'w') do |f|
      f << <<-eos
      digraph G {
          fontname = "Bitstream Vera Sans"
          fontsize = 8
          label = "*** generated by OOOR by www.akretion.com ***"
          node [
                  fontname = "Bitstream Vera Sans"
                  fontsize = 16
                  shape = "record"
                  fillcolor=orange
                  style="rounded,filled"
          ]
          edge [
                  arrowhead = "none"
                  fontname = "Bitstream Vera Sans"
                  fontsize = 9
          ]
      eos

      #UML nodes definitions
      ((connex_classes - classes) + classes - [IrModel, IrModelFields]).each do |model|
        f << " #{model} [ label = \"{#{model.name}#{detailed ? '|' + display_fields(model) : ''}}\" ]"
      end

      #many2one:
      f << <<-eos
          edge [
                headlabel = "1"
                taillabel = "n"
          ]
          eos
      m2o_edges.each do |k, v|
        reverse_part = v[3].size > 0 ? "\\n/#{v[3].join("\\n")}\"]\n" : "\"]\n"
        f << "edge [label = \"#{v[2].join("\\n")}#{reverse_part}"
        f << "#{v[0]} -> #{v[1]}\n"
      end

      #one2many:
      f << <<-eos
          edge [
                headlabel = "n"
                taillabel = "1"
          ]
          eos
      o2m_edges.each do |k, v|
        f << "edge [label = \"#{v[3].join("\\n")}\"]\n"
        f << "#{v[0]} -> #{v[1]}\n"
      end

      #many2many:
      f << <<-eos
          edge [
                headlabel = "n"
                taillabel = "n"
          ]
          eos
      m2m_edges.each do |k, v|
        reverse_part = v[3].size > 0 ? "\\n/#{v[3].join("\\n")}\"]\n" : "\"]\n"
        f << "edge [label = \"#{v[2].join("\\n")}}#{reverse_part}"
        f << "#{v[0]} -> #{v[1]}\n"
      end

      f << "}"
    end

    begin
      cmd_line1 = "rm  uml.png"
      system(cmd_line1)
    rescue
    end
    cmd_line2 = "dot -Tpng uml.dot -o uml.png"
    system(cmd_line2)
  end

  def self.collect_edges(is_reverse, local, classes, enabled_targets, m2o_edges, o2m_edges, m2m_edges)
    connex_classes = Set.new

    classes.each do |model|
      model.reload_fields_definition if model.fields.empty?

      #many2one:
      model.many2one_relations.each do |k, field|
        target = UML.get_target(is_reverse, local, enabled_targets, field, model)
        if target
          connex_classes.add(target)
          if m2o_edges["#{model}-#{target}"]
            m2o_edges["#{model}-#{target}"][2] += [k]
          else
            m2o_edges["#{model}-#{target}"] = [model, target, [k], []]
          end
        end

      end
    end

   classes.each do |model|
      #one2many:
      model.one2many_relations.each do |k, field|
        target = UML.get_target(is_reverse, local, enabled_targets, field, model)
        if target
          connex_classes.add(target)
          if m2o_edges["#{target}-#{model}"]
            m2o_edges["#{target}-#{model}"][3] += [k]
          elsif o2m_edges["#{model}-#{target}"]
            o2m_edges["#{model}-#{target}"][3] += [k]
          else
            o2m_edges["#{model}-#{target}"] = [model, target, [], [k]]
          end
        end
      end

      #many2many:
      model.many2many_relations.each do |k, field|
        target = UML.get_target(is_reverse, local, enabled_targets, field, model)
        if target
          connex_classes.add(target)
          if m2m_edges["#{model}-#{target}"]
            m2m_edges["#{model}-#{target}"][2] += [k]
          elsif m2m_edges["#{target}-#{model}"]
            m2m_edges["#{target}-#{model}"][3] += [k]
          else
            m2m_edges["#{model}-#{target}"] = [model, target, [k], []]
          end
        end
      end

    end
    connex_classes
  end

  private

  def self.get_target(is_reverse, local, enabled_targets, field, model)
    if (is_reverse && !local) || (!enabled_targets) || enabled_targets.index(field.relation)
      target_name = model.class_name_from_model_key(field.relation)
      return Object.const_defined?(target_name) ? Object.const_get(target_name) : model.ooor.define_openerp_model(field.relation, nil, nil, nil, nil, model.scope_prefix)
    end
    return false
  end
end