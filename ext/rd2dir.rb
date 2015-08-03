#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), 'rd-scm.rb')

def rd2dir_init
  if @opt_exclusive
    if ! Dir["#{@opt_store}//**"].empty?
      raise "#{@opt_store}/ is NOT empty. Cannot continue with exclusivity."
    end
  end

  if ! File.exists?("#{@opt_store}")
    FileUtils.mkdir_p("#{@opt_store}")
  end
end

def rdjobs2tree
  tree = Hash.new
  tree['/'] = Hash.new

  project_jobs = fromapi('/1/jobs/export')
  xml_tree = REXML::Document.new(project_jobs)

  xml_tree.elements.each('/joblist/job') { |xml_job|
    if xml_job.elements['group']
      jobdir = xml_job.elements['group'].text
      if ! tree.has_key?(xml_job.elements['group'].text)
        tree[jobdir] = Hash.new
      end
    else
      jobdir = '/'
    end

    job_wrap = REXML::Element.new('joblist')
    job_wrap.add_element(xml_job)
    tree[jobdir][xml_job.elements['name'].text] = job_wrap
  }

  tree
end

def jobstree2dir(jobstree)
  jobstree.each { |subdir, jobs|
    abs_subdir = "#{@opt_store}/#{subdir}"
    if ! File.exists?(abs_subdir)
      FileUtils.mkdir_p(abs_subdir)
    end

    jobs.each { |job_name, job_xml|
      abs_job_file = "#{abs_subdir}/#{job_name}.xml"
      xml_handle = File.open(abs_job_file, 'w')
      @xml_formatter.write(job_xml, xml_handle)
      xml_handle.close
    }
  }
end

if __FILE__==$0
  rd2dir_init
  jobstree = rdjobs2tree
  jobstree2dir(jobstree)
end
