require 'logger'
$logger = Logger.new($stderr)

$:.unshift File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
require 'gene_data_loader'

Dir.glob('for_article/source_data/fantom_cage_files/*.bed').each do |cages_file|
  framework = GeneDataLoaderWithoutPeaks.new(cages_file, 'for_article/source_data/protein_coding_27_05_2013.txt', 'for_article/source_data/knownToLocusLink_hg18.txt', 'for_article/source_data/knownGene_hg18.txt', 100)
  cages_filename = File.basename(cages_file, File.extname(cages_file))

  File.open('for_article/results/' + cages_filename.sub(/\.bed$/,'.txt'), 'w') do |fw|
    framework.output_all_5utr(framework.genes_to_process, fw)
  end
end
