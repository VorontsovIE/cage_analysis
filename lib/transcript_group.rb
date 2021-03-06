require_relative 'transcript'
require_relative 'peak'

# Group transcripts for a gene so that several transcripts having the same
# exon-intron structure on UTR are taken altogether as a TranscriptGroup. Now
# we can treat transcript group, as a single transcript.
# This makes sense because we have no that much information about distinct
# transcripts to distinguish them when their structure on the region of interest
# is the same. So it's useful to just glue them up and treat as one transcript group

class TranscriptGroup
  attr_reader :utr, :exons_on_utr, :transcripts, :associated_peaks
  attr_accessor :summary_expression
  def initialize(utr, exons_on_utr, transcripts, associated_peaks)
    @utr, @exons_on_utr, @transcripts, @associated_peaks = utr, exons_on_utr, transcripts, associated_peaks
    raise 'TranscriptGroup can\'t be empty' if @transcripts.empty?
  end
  # def peaks_associated(peaks, region_length)
  #   # each transcript in group has the same peaks associated so we take one of transcripts to obtain peaks
  #   transcripts.first.peaks_associated(peaks, region_length)
  # end
  def to_s
    exon_infos = exons_on_utr.map{|interval| "#{interval.pos_start}..#{interval.pos_end}"}.join(';')
    transcripts_infos = transcripts.map{|transcript| transcript.name }.join(';')
    "#{transcripts_infos}\tUTR: #{utr}\tExons on UTR: #{exon_infos}"
  end

  def self.groups_with_common_utr(all_transcripts, all_cages)
    all_transcripts.group_by(&:exons_on_utr).map do |exons_on_utr, transcripts|
      sample_transcript = transcripts.first
      # all transcripts with the same exons_on_utr also have tha same 5'-UTRs
      utr = sample_transcript.utr_5
      # and the same peaks
      sample_transcript.peaks_associated.select{|peak| sum_cages(peak & exons_on_utr, all_cages) == 0 }.each{|peak|
        real_sum_cages = sum_cages(peak.region, all_cages)
        $stderr.puts "Peak #{peak} was removed from associated peaks of a transcript group because its sum of cages on intersection with #{sample_transcript}'s UTR is zero (full sum of cages of a peak is #{ real_sum_cages })"
      }
      associated_peaks = sample_transcript.peaks_associated.reject{|peak| sum_cages(peak & exons_on_utr, all_cages) == 0 }
      TranscriptGroup.new(utr, exons_on_utr, transcripts, associated_peaks)
    end
  end

end
