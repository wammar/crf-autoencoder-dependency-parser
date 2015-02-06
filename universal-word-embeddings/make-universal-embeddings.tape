#!/usr/bin/env ducttape

global {
  ducttape_experimental_submitters=enable
  ducttape_experimental_imports=enable

  # experiments directory
  ducttape_output="/usr3/home/wammar/exp-universal-embeddings"

  # data
  languages="english|french|spanish|german"
  target_language=(Target: english="en" spanish="es" french="fr" german="de")
  en_corpus="/usr3/home/wammar/corpora/monolingual/plain-en/news.2008-2012+nc.v8+ud.v1.lc.tok.10k"
  fr_corpus="/usr3/home/wammar/corpora/monolingual/plain-fr/news.2008-2012+nc.v8+ud.v1.lc.tok.10k"
  es_corpus="/usr3/home/wammar/corpora/monolingual/plain-es/news.2008-2012+nc.v8+ud.v1.lc.tok.10k"
  de_corpus="/usr3/home/wammar/corpora/monolingual/plain-de/news.2008-2012+nc.v8+ud.v1.lc.tok.10k"
  en_universal_treebank="/usr3/home/wammar/corpora/universal-dependencies-1.0/treebanks/en/en-ud-all.conllu"
  fr_universal_treebank="/usr3/home/wammar/corpora/universal-dependencies-1.0/treebanks/fr/fr-ud-all.conllu"
  es_universal_treebank="/usr3/home/wammar/corpora/universal-dependencies-1.0/treebanks/es/es-ud-all.conllu"
  de_universal_treebank="/usr3/home/wammar/corpora/universal-dependencies-1.0/treebanks/de/de-ud-all.conllu"
  
  wiktionary_raw_translations="/usr0/home/wammar/multilingual-embeddings/wiktionary-transliations/wiktionary_de+en_2012-04-01_translations.csv.gz"

  # tools
  eacl14_cca="/usr0/home/wammar/git/eacl14-cca/"
  word2vec="/opt/tools/word2vec/word2vec-waleed"
  wiktionary_miner="/usr0/home/wammar/multilingual-embeddings/wiktionary-transliations/multilingual-to-bilingual-dictionaries.py"
  conll_eval="/usr0/home/wammar/wammar-utils/conllx-eval.v1_8.pl"
  wammar_utils="/usr0/home/wammar/wammar-utils/"

  # options
  word2vec_size=80
  word2vec_window=2
  word2vec_mincount=1
  wiktionary_lowercase="-lowercase"
}

task MakeBilingualDictionaries
  :: wiktionary_raw_translations=@
  :: languages=@
  :: wiktionary_lowercase=@
  :: wiktionary_miner=@
  >  bilingual_dictionaries
{
  python $wiktionary_miner -rawfile $wiktionary_raw_translations -outdir $bilingual_dictionaries -langs $languages $wiktionary_lowercase
}

task MakeMonolingualEmbeddings
  :: word2vec=@
  :: word2vec_size=@
  :: word2vec_window=@
  :: word2vec_mincount=@

  :: en_corpus=@
  >  en_embeddings
  :: fr_corpus=@
  >  fr_embeddings
  :: es_corpus=@
  >  es_embeddings
  :: de_corpus=@
  >  de_embeddings
{
  $word2vec -train $en_corpus -size $word2vec_size -window $word2vec_window -min-count $word2vec_mincount -output $en_embeddings
  $word2vec -train $es_corpus -size $word2vec_size -window $word2vec_window -min-count $word2vec_mincount -output $es_embeddings
  $word2vec -train $fr_corpus -size $word2vec_size -window $word2vec_window -min-count $word2vec_mincount -output $fr_embeddings
  $word2vec -train $de_corpus -size $word2vec_size -window $word2vec_window -min-count $word2vec_mincount -output $de_embeddings
}

task ProjectEmbeddingsToEnglishSpace
  :: eacl14_cca=@
  <  en_embeddings=$en_embeddings@MakeMonolingualEmbeddings
  <  de_embeddings=$de_embeddings@MakeMonolingualEmbeddings
  <  es_embeddings=$es_embeddings@MakeMonolingualEmbeddings
  <  fr_embeddings=$fr_embeddings@MakeMonolingualEmbeddings
  <  bilingual_dictionaries=$bilingual_dictionaries@MakeBilingualDictionaries
  >  de_en_space_transformation
  >  de_embeddings_in_en_space
  >  es_en_space_transformation
  >  es_embeddings_in_en_space
  >  fr_en_space_transformation
  >  fr_embeddings_in_en_space
  >  merged_embeddings_in_en_space
{
  pushd $eacl14_cca
  $eacl14_cca/project_vectors_to_lang2.sh $de_embeddings $en_embeddings $bilingual_dictionaries/german-english $de_en_space_transformation $de_embeddings_in_en_space
  $eacl14_cca/project_vectors_to_lang2.sh $es_embeddings $en_embeddings $bilingual_dictionaries/spanish-english $es_en_space_transformation $es_embeddings_in_en_space
  $eacl14_cca/project_vectors_to_lang2.sh $fr_embeddings $en_embeddings $bilingual_dictionaries/french-english $fr_en_space_transformation $fr_embeddings_in_en_space
  popd
  awk '{$0="en:"$0} {print $0}' $en_embeddings > $merged_embeddings_in_en_space
  awk '{$0="de:"$0} {print $0}' $de_embeddings_in_en_space >> $merged_embeddings_in_en_space
  awk '{$0="fr:"$0} {print $0}' $fr_embeddings_in_en_space >> $merged_embeddings_in_en_space
  awk '{$0="es:"$0} {print $0}' $es_embeddings_in_en_space >> $merged_embeddings_in_en_space  
}

task MergeUniversalDependencyTreebanks
  :: en_universal_treebank=@
  :: es_universal_treebank=@
  :: de_universal_treebank=@
  :: fr_universal_treebank=@
  :: wammar_utils=@
  :: target_language=@
  >  train_treebank
  >  test_treebank
{
  touch temp_train_treebank

  if [[ $target_language == "en" ]]; then
    awk 'BEGIN {OFS="\t"} length {$2="en:"$2} {print $0}' $en_universal_treebank >  temp_test_treebank
  else
    awk 'BEGIN {OFS="\t"} length {$2="en:"$2} {print $0}' $en_universal_treebank >> temp_train_treebank
  fi

  if [[ $target_language == "fr" ]]; then
    awk 'BEGIN {OFS="\t"} length {$2="fr:"$2} {print $0}' $fr_universal_treebank > temp_test_treebank
  else
    awk 'BEGIN {OFS="\t"} length {$2="fr:"$2} {print $0}' $fr_universal_treebank >> temp_train_treebank
  fi

  if [[ $target_language == "es" ]]; then
    awk 'BEGIN {OFS="\t"} length {$2="es:"$2} {print $0}' $es_universal_treebank >  temp_test_treebank
  else 
    awk 'BEGIN {OFS="\t"} length {$2="es:"$2} {print $0}' $es_universal_treebank >>  temp_train_treebank
  fi

  if [[ $target_language == "de" ]]; then
    awk 'BEGIN {OFS="\t"} length {$2="de:"$2} {print $0}' $de_universal_treebank >  temp_test_treebank
  else
    awk 'BEGIN {OFS="\t"} length {$2="de:"$2} {print $0}' $de_universal_treebank >>  temp_train_treebank
  fi

  python $wammar_utils/lowercase.py -i temp_test_treebank -o $test_treebank
  python $wammar_utils/lowercase.py -i temp_train_treebank -o $train_treebank
}

task TrainTestTurboParser
  <  test=$test_treebank@MergeUniversalDependencyTreebanks
  <  train=$train_treebank@MergeUniversalDependencyTreebanks
  <  embeddings=$merged_embeddings_in_en_space@ProjectEmbeddingsToEnglishSpace
  >  model
  >  prediction
{
  touch $model
  cp $test $prediction
}

task EvaluatePrediction
  <  prediction=$prediction@TrainTestTurboParser
  <  test_treebank=$test_treebank@MergeUniversalDependencyTreebanks
  >  scores
  :: conll_eval=@
{
  perl $conll_eval -g $test_treebank -s $prediction > $scores
}

plan Debug {
#  reach MakeMonolingualEmbeddings
#  reach MakeBilingualDictionaries
#  reach ProjectEmbeddingsToEnglishSpace
#  reach MergeUniversalDependencyTreebanks via (Target: spanish)
  reach EvaluatePrediction via (Target: spanish)
#  reach TrainTestTurboParser via (Target: spanish)
}
