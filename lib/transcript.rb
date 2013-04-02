$:.unshift File.dirname(File.expand_path(__FILE__))
require 'region'
require 'peak'

class Transcript
  attr_reader :name, :chromosome, :strand, :full_gene_region, :coding_region, :exons, :protein_id, :align_id

  def initialize(name, chromosome, strand, full_gene_region, coding_region, exons, protein_id, align_id)
    @name, @chromosome, @strand, @full_gene_region, @coding_region, @exons, @protein_id, @align_id  = name, chromosome, strand, full_gene_region, coding_region, exons, protein_id, align_id
  end

  # Transcript.new_by_infos('uc001aaa.3 chr1  + 11873 14409 11873 11873 3 11873,12612,13220,  12227,12721,14409,    uc001aaa.3')
  # We don't remove version from name not to have a bug with  uc010nxr.1(chr1)  and  uc010nxr.2(chrY)
  # Be careful about real versions of transcripts, use synchronized databases
  def self.new_by_infos(info)
    name, chromosome, strand, tx_start, tx_end, cds_start, cds_end, exon_count, exon_starts, exon_ends, protein_id, align_id = info.split("\t")
    exon_starts = exon_starts.split(',').map(&:strip).reject(&:empty?).map(&:to_i)
    exon_ends = exon_ends.split(',').map(&:strip).reject(&:empty?).map(&:to_i)
    full_gene_region = Region.new(chromosome, strand, tx_start.to_i, tx_end.to_i)
    coding_region = Region.new(chromosome, strand, cds_start.to_i, cds_end.to_i)
    exons = exon_count.to_i.times.map{|index| Region.new(chromosome, strand, exon_starts[index], exon_ends[index]) }
    self.new(name, chromosome, strand, full_gene_region, coding_region, exons, protein_id, align_id)
  end
  
  def to_s
    "Transcript<#{name}; #{chromosome},#{strand}; with coding_region #{coding_region}>"
  end
  
  # region_length is length of region before txStart(start of transcript) where we are looking for peaks
  def peaks_associated(peaks, region_length)
    if strand == '+'
      region_of_interest = Region.new(chromosome, strand, full_gene_region.pos_start - region_length, coding_region.pos_start)
    else
      region_of_interest = Region.new(chromosome, strand, coding_region.pos_end, full_gene_region.pos_end + region_length)
    end
    peaks.select{|peak| region_of_interest.intersect?(peak.region)}
  end
  
  # region_length is length of region before txStart(start of transcript) where we are looking for peaks
  # utr_region is defined by leftmost peak intersecting region [txStart-region_length; coding_region_start) and by start of coding region
  def utr_region(peaks, region_length)
    associated_peaks = peaks_associated(peaks, region_length)
    if associated_peaks.empty?
      $logger.warn "#{self} has no associated peaks"
      return nil
    end
    
    if strand == '+'
      utr_start = associated_peaks.map{|peak| peak.region.pos_start}.min
      utr_end = coding_region.pos_start
    else
      utr_end = associated_peaks.map{|peak| peak.region.pos_end}.max
      utr_start = coding_region.pos_end
    end
    if utr_start > utr_end
      $logger.error "#{gene}'s UTR can't be evaluated: utr_start=#{utr_start} > utr_end=#{utr_end}"
      return nil
    end
    Region.new(chromosome, strand, utr_start, utr_end)
  end
  
  # region --> [regions]
  
  # |   (         )       
  # |      |--| |---| |--|
  # V 
  #        |--| |-|
  def exons_on_region(region)
    exons_inside = []
    exons.each do |exon|
      exons_inside << region.intersection(exon)  if region.intersect?(exon)
    end
    exons_inside
  end

  # ucsc_id => transcript
  def self.transcripts_from_file(input_file)
    transcripts = {}
    File.open(input_file) do |fp|
      fp.each_line do |line|
        transcript = Transcript.new_by_infos(line)
        transcripts[transcript.name] = transcript
      end
    end
    transcripts
  end

end