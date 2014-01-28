$:.unshift File.dirname(File.expand_path(__FILE__))
require 'intervals/genome_region'
require 'transcript'
require 'peak'
require 'transcript_group'

class Gene
  attr_reader :hgnc_id, :approved_symbol, :approved_name

  attr_reader :chromosome_map, :entrezgene_id
  attr_accessor :transcripts, :peaks

  def initialize(hgnc_id, approved_symbol, approved_name, chromosome_map, entrezgene_id)
    @hgnc_id, @approved_symbol, @approved_name, @chromosome_map, @entrezgene_id = hgnc_id, approved_symbol, approved_name, chromosome_map, entrezgene_id
    @transcripts = []
    @peaks = []
  end

  # Gene.new_by_infos('HGNC:10000 RGS4  regulator of G-protein signaling 4  1q23.3  5999')
  def self.new_by_infos(infos)
    hgnc_id, approved_symbol, approved_name, chromosome_map, entrezgene_id = infos.strip.split("\t")
    hgnc_id = hgnc_id.split(':',2).last.to_i
    if entrezgene_id && entrezgene_id.empty?
      entrezgene_id = nil
    else
      entrezgene_id = entrezgene_id.to_i
    end
    self.new(hgnc_id, approved_symbol, approved_name, chromosome_map, entrezgene_id)
  end

  def to_s
    "Gene<HGNC:#{hgnc_id}; #{approved_symbol}; entrezgene:#{entrezgene_id}; #{transcripts.map(&:to_s).join(', ')}; have #{peaks.size} peaks>"
  end

  # returns loaded transripts or false if due to some reasons transcripts can't be collected
  def collect_transcripts(entrezgene_transcripts, all_transcripts)
    unless entrezgene_id
      $logger.warn "#{self} has no entrezgene_id so we cannot find transcripts"
      return false
    end

    transcripts = []
    transcript_ucsc_ids = entrezgene_transcripts[entrezgene_id] || []
    transcript_ucsc_ids.each do |ucsc_id|
      transcript = all_transcripts[ucsc_id]
      if !transcript
        $logger.error "#{self}'s transcript with #{ucsc_id} wasn't found. Skip transcript"
      elsif ! transcript.coding?
        $logger.warn "#{self}'s #{transcript} has no coding region. Skip transcript"
      else
        transcripts << transcript
      end
    end

    if transcripts.empty?
      $logger.error "No one transcript of #{self} was found"
      return false
    end
    self.transcripts = transcripts
  end

  # returns loaded peaks or false if due to some reasons peaks can't be collected
  def collect_peaks(all_peaks)
    if all_peaks.has_key?(hgnc_id)
      self.peaks = all_peaks[hgnc_id]
    else
      $logger.warn "#{self} has no peaks in this cell line"
      false
    end
  end

  # {[utr, exons_on_utr] => [transcripts]}
  def transcripts_grouped_by_common_exon_structure_on_utr(region_length, all_cages)
    groups_of_transcripts = {}
    group_associated_peaks = {}
    transcripts.each do |transcript|
      utr = transcript.utr_region
      exons_on_utr = transcript.exons_on_utr

      if utr.empty? || exons_on_utr.empty?
        $logger.info "#{transcript} with utr #{utr} has no exons on utr #{exons_on_utr}"
        next
      end

      associated_peaks = transcript.peaks_associated.select do |peak|
        peaks_on_exons = peak.intersection(exons_on_utr)
        sum_cages_on_exons = peaks_on_exons.each_region.map{|region| region.load_cages(all_cages).inject(0,:+) }.inject(0, :+)
        if sum_cages_on_exons == 0
          $logger.info "#{transcript}\tpeaks_on_exons: #{peaks_on_exons}\t has zero sum of cages on exons"
          false
        else
          true
        end
      end

      if associated_peaks.empty?
        $logger.info "#{transcript} has no associated peaks on utr"
        next
      end

      exon_intron_structure_on_utr = [utr, exons_on_utr]  # utr should be here to know boundaries
      groups_of_transcripts[exon_intron_structure_on_utr] ||= []
      groups_of_transcripts[exon_intron_structure_on_utr] << transcript
      group_associated_peaks[exon_intron_structure_on_utr] = associated_peaks
    end

    groups_of_transcripts.map{|exon_intron_structure_on_utr, transcripts|
      utr, exons_on_utr = exon_intron_structure_on_utr
      TranscriptGroup.new(utr, exons_on_utr, transcripts, group_associated_peaks[exon_intron_structure_on_utr])
    }
  end

  # hgnc_id => gene
  def self.genes_from_file(input_file)
    genes = {}
    File.open(input_file) do |fp|
      fp.each_line do |line|
        next if fp.lineno == 1
        gene = Gene.new_by_infos(line)
        genes[gene.hgnc_id] = gene
      end
    end
    genes
  end
end
