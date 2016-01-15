augr class
au!
au bufreadpost,filereadpost *.class %!d:jad.exe -noctor -ff -i -p %
au bufreadpost,filereadpost *.class set readonly
au bufreadpost,filereadpost *.class set ft=java
au bufreadpost,filereadpost *.class normal gg=G
au bufreadpost,filereadpost *.class set nomodified
augr END
