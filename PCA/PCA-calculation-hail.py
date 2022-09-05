import hail as hl
hl.init()

grar_mt  = hl.read_matrix_table("<GRAR MT>")
onekg_mt = hl.read_matrix_table("<1KPG3 MT>") 
sabe_mt = hl.read_matrix_table("<SABE MT>") 

mt = grar_mt.select_entries('GT').union_cols(onekg_mt.drop('sample_data'))
mt = grar_mt.union_cols(sabe_mt.select_entries('GT'))

eigenvalues, pcs, _ = hl.hwe_normalized_pca(mt.GT)

mt = mt.annotate_cols(scores = pcs[mt.s].scores)

mt.cols().export('<PCA OUTPUT>.tsv', delimiter = '\t')