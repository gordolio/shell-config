#export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
if [[ -d /Library/Java/JavaVirtualMachines/jdk1.7.0_79.jdk/Contents/Home ]]; then
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.7.0_79.jdk/Contents/Home"
else
  export JAVA_HOME="/opt/jdk1.7.0_79"
fi

export JVM_ARGS="-Xms1024m -Xmx1024m"
export MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=512m"


switchJava() {
   if [[ $JAVA_VERSION == "1.7" ]]; then
      export JAVA_VERSION="1.8"
      export MAVEN_OPTS="-Xmx1024m"
      export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
   elif [[ $JAVA_VERSION == "1.8" ]]; then
      export JAVA_VERSION="9"
      export MAVEN_OPTS="-Xmx1024m"
      export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
   else
      export JAVA_VERSION="1.7"
      export MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=512m"
      export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
   fi
   echo "Switching to java $JAVA_VERSION"
}
export STUDIO_JDK=$JAVA_HOME
