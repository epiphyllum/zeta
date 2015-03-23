{
    # 组织资源插入$sync
    initor => sub {
        my $sync = shift;
        my $dbh = $sync->{dst}{dbh};
        my $qsql_mcht = "select mname from mcht_inf where mid = ?";
        my $sth = $dbh->prepare($qsql_mcht);
        unless($sth) {
            confess "can not prepare[$qsql_mcht]";
        }
        $sync->{_mcht} = $sth,
    },

    insert => sub {
        my ($sync, $slog) = @_;
        my $sth_mcht = $sync->{_mcht};
        #----------------------------------------
        # slog: 
        #----------------------------------------
        # 0 sys_date        is '交易日期';
        # 1 sys_time        is '交易时间 ';
        # 2 busitype        is '业务类型';
        # 3 busioper        is '业务操作方向';
        # 4 apptype         is '交易类型';
        # 5 psam            is 'Psam卡号';
        # 6 fwd_ins_id_cd   is '交易上送机构号★';
        # 7 rcv_ins_id_cd   is '渠道机构号';
        # 8 fld32_ins_id_cd is '受理机构号';
        # 1 loc_trans_tm    is '上送交易时间★';
        # 1 loc_trans_dt    is '上送交易日期';
        # 1 card_attr       is '卡属性';
        # 1 iss_ins_id_cd   is '发卡行代码';
        # 1 outpan          is '转出账户';
        # 1 name            is '户名';
        # 1 licensetype     is '证件类型';
        # 1 license         is '证件号码';
        # 1 inpan           is '转入账户';
        # 1 amount          is '交易金额';
        # 1 payamount       is '手续费';
        # 1 settledate      is '清算日期';
        # 1 pos_entry_md_cd is '服务点输入方式码';
        # 1 pos_cond_cd     is '服务点条件码';
        # 1 auth_id_resp_cd is '授权码';
        # 1 trans_curr_cd   is '交易币种';
        # 1 ordernumber     is '订单号（适用电力客户号等）';
        # 1 entrymsgid      is '进入通道报文头';
        # 1 entryproccode   is '进入通道处理码';
        # 1 entrychannele   is '进入通道类型';
        # 1 entryfoldid     is '进入通道fold ID';
        # 1 entryseqno      is '进入通道流水号★';
        # 1 entryshopid     is '进入通道商户号';
        # 1 entrytermid     is '进入通道终端号';
        # 1 appmsgid        is '渠道方通道报文头';
        # 1 appproccode     is '渠道方通道处理码';
        # 1 appchannele     is '渠道方通道类型';
        # 1 appfoldid       is '渠道方通道fold ID';
        # 1 appseqno        is '渠道方通道流水号';
        # 1 apprefnbr       is '渠道方通道系统参考号';
        # 1 appshopid       is '渠道方通道商户号';
        # 1 apptermid       is '渠道方通道终端号';
        # 1 appretcode      is '渠道方通道应答码';
        # 1 centerretcode   is '中心应答码';
        # 1 busiflag        is '业务状态标识';
        # 1 voidflag        is '冲正标识';
        # 1 settleflag      is '清算标识';
        # 1 addidata1       is '业务附加数据1';
        # 1 addidata2       is '业务附加数据2';
        # 1 area            is '区号';
        # 1 tel             is '电话号码';
        # 1 paymsgid        is '扣款方通道报文头';
        # 1 payproccode     is '扣款方通道处理码';
        # 1 paychannele     is '扣款方通道类型';
        # 1 payfoldid       is '扣款方通道fold ID';
        # 1 payseqno        is '扣款方通道流水号';
        # 1 payrefnbr       is '扣款方通道系统参考号';
        # 1 payshopid       is '扣款方通道商户号';
        # 1 paytermid       is '扣款方通道终端号';
        # 1 payretcode      is '扣款方通道应答码';
        # 1 app_ins_id_cd   is '银行代码';
        # 1 timestamp       is '时间戳';
        #----------------------------------------
        # dlog  
        #----------------------------------------
        my $mname;  # 商户名称地址
        $sth_mcht->execute();
        my $row = $sth_mcht->fetchrow_hashref();
        my $mname = $row->{mname};
        
        my $dlog =  [ 
            $slog->[0] . $slog->[1],   
            $slog->[2],
            $slog->[3], 
            $slog->[2] . $slog->[3], 
            $slog->[4] 
        ];
        use Data::Dump;
        Data::Dump->dump($slog, $dlog);
        return $dlog;
    },

    #  更新: 
    update => sub {
        my ($sync, $slog) = @_;
        #----------------------------------------
        # dlog   [ u12, ts_u, $k12 ];
        #----------------------------------------
        my $dlog =  [ 
            $slog->[2] . $slog->[3], 
            $slog->[4],
            $slog->[0] . $slog->[1],   
        ],
    }
};


__END__


