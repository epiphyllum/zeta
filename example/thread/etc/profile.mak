export ZETA_HOME=$HOME/workspace/zeta
export THREAD_HOME=$HOME/workspace/zeta/example/thread
export PERL5LIB=$ZETA_HOME/lib::$THREAD_HOME/lib
export PLUGIN_PATH=$THREAD_HOME/plugin
export PATH=$THREAD_HOME/bin:$THREAD_HOME/sbin:$ZETA_HOME/bin:$PATH

export DB_NAME=zdb_cs
export DB_USER=ypinst
export DB_PASS=ypinst
export DB_SCHEMA=ypinst
alias dbc='db2 connect to $DB_NAME user $DB_USER using $DB_PASS'

alias cdl='cd $THREAD_HOME/log';
alias cdd='cd $THREAD_HOME/data';
alias cdlb='cd $THREAD_HOME/lib/THREAD';
alias cdle='cd $THREAD_HOME/libexec';
alias cdb='cd $THREAD_HOME/bin';
alias cdsb='cd $THREAD_HOME/sbin';
alias cdc='cd $THREAD_HOME/conf';
alias cde='cd $THREAD_HOME/etc';
alias cdt='cd $THREAD_HOME/t';
alias cdh='cd $THREAD_HOME';
alias cdtb='cd $THREAD_HOME/sql/table';
