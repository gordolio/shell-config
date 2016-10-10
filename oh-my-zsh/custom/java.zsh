

#export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
if [[ -d /Library/Java/JavaVirtualMachines/jdk1.7.0_79.jdk/Contents/Home ]]; then
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.7.0_79.jdk/Contents/Home"
elif [[ -d /cygdrive/c/ProgFiles/Java/jdk1.8.0_101 ]]; then
   export JAVA_HOME="/cygdrive/c/ProgFiles/Java/jdk1.8.0_101"
else
  export JAVA_HOME="/opt/jdk1.7.0_79"
fi

export JVM_ARGS="-Xms1024m -Xmx1024m"
export MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=512m"


switchJava() {
   if [[ ! -x /usr/libexec/java_home ]]; then
      echo "/usr/libexec/java_home not found!" 1>&2
      return
   fi
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

alias java="$JAVA_HOME/bin/java"
alias javac="$JAVA_HOME/bin/javac"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

