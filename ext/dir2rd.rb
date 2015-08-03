#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), 'rd-scm.rb')
require File.join(File.dirname(__FILE__), 'rd2dir.rb')

def dir2jobsxml
  @dir_job_uuids = Set.new
  jobsxml = REXML::Element.new('joblist')
  xml_files = Dir["#{@opt_store}/**/*.xml"]
  job_count = 0
  xml_files.each { |xml_file|
    job_xml = REXML::Document.new(File.read(xml_file))
    job_xml = job_xml.elements['joblist/job']
    @dir_job_uuids.add(job_xml.elements['uuid'].text)
    project_name_old = job_xml.elements['context'].elements['project'].text
    project_name_new = @opt_project
    if project_name_old != project_name_new
      job_xml.delete_element(job_xml.elements['id'])
      job_xml.delete_element(job_xml.elements['uuid'])
      job_xml.elements['context'].elements['project'].text = @opt_project
    end
    jobsxml.add_element(job_xml)
    job_count += 1
  }
  puts "Loaded #{job_count} jobs from #{@opt_store} ."
  jobsxml
end

def jobsxml2rd(jobsxml)
  var_params = Hash.new
  var_files = Hash.new
  var_params['format'] = 'xml'
  var_params['dupeOption'] = 'update'
  var_params['project'] = @opt_project
  var_params['uuidOption'] = 'preserve'
  var_files['xmlBatch'] = jobsxml.to_s
  imported_jobs = toapi('/1/jobs/import', var_params, var_files)
  xml_tree = REXML::Document.new(imported_jobs)
  imported_job_uuids = Set.new
  xml_tree.elements.each('/result/succeeded/job') { |xml_job|
    imported_job_uuids.add(xml_job.elements['id'].text)
  }
  puts "Imported #{imported_job_uuids.length} jobs into Rundeck API."
  if @opt_exclusive
    jobstree = rdjobs2tree
    rd_job_uuids = Set.new
    jobstree.each { |group, jobs|
      jobs.each { |job_name, job_xml|
        rd_job_uuids.add(job_xml.elements['job/uuid'].text)
      }
    }
    excess_job_uuids = rd_job_uuids - @dir_job_uuids - imported_job_uuids
    if ! excess_job_uuids.empty?
      var_params['idlist'] = excess_job_uuids.to_a.join(',')
      deleted_jobs = toapi('/5/jobs/delete',  var_params)
      xml_tree = REXML::Document.new(deleted_jobs)
      deleted_job_uuids = Set.new
      xml_tree.elements.each('/result/deleteJobs/succeeded/deleteJobResult') { |xml_job|
        deleted_job_uuids.add(xml_job.elements['message'].text)
      }
      puts "Deleted #{deleted_job_uuids.length} jobs from Rundeck API."
    end
  end
end

if __FILE__==$0
  begin
    jobsxml = dir2jobsxml
    jobsxml2rd(jobsxml)
  rescue Exception => e
    $stderr.puts e.message
    exit 249
  end
end
