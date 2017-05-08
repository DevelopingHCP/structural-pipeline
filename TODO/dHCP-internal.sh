
if [ ! -f dofs/$subj-template-$age-r.dof.gz ];then
  run mirtk convert-dof dofs/$subj-template-$age-n.dof.gz dofs/$subj-template-$age-r.dof.gz -input-format mirtk -output-format rigid
fi