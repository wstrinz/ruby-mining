require 'java'

module Core
  module Type
    
    java_import "weka.core.Instances"
    java_import 'java.io.File'
    java_import 'weka.core.converters.CSVSaver'
    java_import 'weka.core.converters.ArffSaver'
    java_import "weka.core.FastVector"
    java_import "weka.core.Instance"

    #
    # * *Description*    :
    # This is the main class from the Weka package for data handling. It is essentially a matrix: each row
    # is an instance of the 'Instance' class, while each column is an instance of the 'Attribute' class
    # The class 'Instances' is here extended to add custom functionalities 
    class Instances

      # Convert an Instances object to a bidimensional Ruby array
      # where each row corresponds to an Instance object
      def to_a2d
        matrix = Array.new
        att = Array.new
        self.enumerateAttributes.each_with_index do |a,idx|
          if a.isNumeric  
            enumerate_instances.each {|s| att << s.value(s.attribute(idx))}
            matrix << att
            att = Array.new
          else
            enumerateInstances.each do |inst|
              att << inst.string_value(idx)
            end
            matrix << att
            att = Array.new
          end
        end
        return matrix.transpose
      end

      # Check if this instance's attributes are all Numeric
      def check_numeric_instance
        enumerateAttributes.each do |att|
          unless att.isNumeric
            raise ArgumentError, "Sorry, attribute '#{att.name}' is not numeric!"
          end
        end
      end

      # Convert the present Instances object to an Apache matrix if every Instances attribute
      # is Numeric 
      def to_Apache_matrix
        check_numeric_instance
        ruby_array = to_a
        java_double_array = Core::Utils::bidimensional_to_double(ruby_array)
        return Core::Type::Apache_matrix.new(java_double_array)
      end

      # Convert the present Instances object to an Apache matrix (block) if every Instances attribute
      # is Numeric 
      def to_Apache_matrix_block
        check_numeric_instance
        ruby_array = to_a
        java_double_array = Core::Utils::bidimensional_to_double(ruby_array)
        return Core::Type::Apache_matrix_block.new(java_double_array)
      end

      # Return data for a single attribute (a column from the Instances object)
      # * *Args*    :
      #   - +att+ -> a String, the name of the attribute
      def return_attr_data(att)
        attr_values = Array.new
        if attribute(att).isNumeric
          enumerateInstances.each do |i|
            attr_values << i.value(attribute(att))
          end
        else
          attr_index = attribute(att).index
          enumerateInstances.each do |inst|
            attr_values << inst.string_value(attr_index)
          end
        end
        return attr_values
      end

      # Return the mean value of a single attribute (a column from the Instances object)
      # * *Args*    :
      #   - +attribute_name+ -> a String, the name of the attribute      
      def mean(attribute_name) 
        sum = enumerateInstances.inject(0) do |s,x|
          s+=x.value(attribute(attribute_name))
        end
        return sum/(numInstances*1.0)
      end

      # Return the variance of a single attribute (a column from the Instances object)
      # * *Args*    :
      #   - +attribute_name+ -> a String, the name of the attribute    
      def mean(attribute_name) 
        enumerateAttributes.each_with_idx do |att,idx|
          return variance(idx) if att.name==attribute_name
        end
      end      

      # Write the content of the current Instances object to a .csv file
      # * *Args*    :
      #   - +out_file+ -> a String, the name of the output file  
      def to_CSV(out_file)
        saver = CSVSaver.new
        saver.setInstances(self)
        out_file = File.new out_file
        saver.setFile(out_file);
        saver.writeBatch();
      end

      # Write the content of the current Instances object to a .arff file
      # * *Args*    :
      #   - +out_file+ -> a String, the name of the output file 
      def to_ARFF(out_file)
        saver = ArffSaver.new
        saver.setInstances(self)
        out_file = File.new out_file
        saver.setFile(out_file);
        saver.writeBatch();
      end

      # (check function): should check that the array is bidimensional and that
      # the lengths are equal
      def check_array(data)
        return true
      end

      # An entire dataset is inserted 'by row' into the current Instances object 
      # i.e. one Instance object is inserted at the time
      # * *Args*    :
      #   - +data+ -> a bidimensional array 
      def populate_by_row(data)
        unless check_array(data) == false
          data.each do |row|
            insert_instance(row)
          end
        end
      end

      # An Instance instance object is inserted into the current Instances object 
      # * *Args*    :
      #   - +instance+ -> an Instance object
      def insert_instance(instance)
        data_ref=Array.new
        instance.each_with_index do |attribute,idx|
          data_ref << insert_attribute(attribute,idx)
        end
        double_array = data_ref.to_java :double
        single_row = Instance.new(1.0, double_array)
        self.add(single_row)
      end

      # An Attribute instance object is inserted into the current Instances object  
      # * *Args*    :
      #   - +attribute_name+ -> A name for the new attribute
      # * *WARNING*    :
      # This method only creates an empty attribute field
      def insert_numeric_attribute(attribute_name)
        insertAttributeAt(Attribute.new(attribute_name), self.numAttributes)
      end

      # An Attribute instance object is inserted into the current Instances object  
      # * *Args*    :
      #   - +attribute_name+ -> A name for the new attribute
      #   - +values+ -> RubyArray with nominal values 
      # * *WARNING*    :
      # This method only creates an empty attribute field
      def insert_nominal_attribute(attribute,list_values)
        values = FastVector.new
        list_values.each do |val|
          values.addElement(val)         
        end
        insertAttributeAt(Attribute.new(attribute, values), self.numAttributes)
      end      

      #Print to STDOUT the list of the Instances's attributes (with the corresponding types)
      def summary
        enumerateAttributes.each_with_index do |att,idx| 
          STDOUT.write "Attribute #{idx}\t"
        end
        STDOUT.write "\n"        
        enumerateAttributes.each do |att| 
          STDOUT.write "#{att.name}\t"
        end
        STDOUT.write "\n"
        enumerateAttributes.each do |att|
          STDOUT.write "Numeric\t" if att.isNumeric 
          STDOUT.write "Nominal\t" if att.isNominal
          STDOUT.write "Date\t" if att.isDate
        end
        count=0
        enumerateInstances.each {|inst| count=count+1}
        puts "\nNumber of rows: #{count}" 
      end

      # Merges two sets of Instances together. The resulting set will have all the
      # attributes of the first set plus all the attributes of the second set. The
      # number of instances in both sets must be the same.
      # * *Args*    :
      #   - +instances+ -> An Instances class object
      def merge_with(instances)
        return Instances.mergeInstances(self,instances)
      end

    end #Instances class

    # Create an Instances object
    # * *Args*    :
    #   - +name+ -> A name for the Instances object
    #   - +attributes+ -> An array containing Attribute objects
    def Type.create_instances(name,attributes)
      attributes_vector = FastVector.new
      attributes.each {|value| attributes_vector.addElement(value)}
      return Instances.new(name,attributes_vector,0)
    end
  end
end



