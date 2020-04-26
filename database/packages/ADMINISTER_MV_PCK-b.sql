create or replace package body administer_mv_pck as
  procedure get_next_mv(p_session_id in raw);

  procedure get_mv_log_data(po_json_object out varchar) is
    v_json_obj varchar2(4000);
  begin
    --tiek atgriezts saraksts ar visiem MV uz ko shemai ir tiesibas, ja te paradisies kadi lieki MV (sistemas utt, tad jataisa WHERE dala filtracija nost)
    --atgriezam JSON string uz backend, kas talak to nodos frontendam attelosanai
    select jSON_ARRAYAGG(JSON_OBJECT('owner' value owner,
                             'mvName' value mv_name,
                          'startDate' value to_Char(start_time, 'dd.mm.yyyy'),  
                                'endDate 'value to_Char(end_time, 'dd.mm.yyyy'),  
                                'dependencyPath' value dependency_path) order by m.priority desc nulls last)
                                into v_json_obj
    from MV_REFRESH_LOG m
      where session_id = (select session_id from mv_refresh_log where start_time = (select max(start_time) from mv_refresh_log) and rownum = 1);
  
    po_json_object := v_json_obj;
  exception
    when no_data_found then
      po_json_object := null;
  end get_mv_log_data;
  
  procedure get_mv_list_with_priorities(po_json_object out varchar) is
    v_json_obj varchar2(4000);
  begin
    --tiek atgriezts saraksts ar visiem MV uz ko shemai ir tiesibas, ja te paradisies kadi lieki MV (sistemas utt, tad jataisa WHERE dala filtracija nost)
    --atgriezam JSON string uz backend, kas talak to nodos frontendam attelosanai
    select JSON_ARRAYAGG(JSON_OBJECT('owner' value m.owner,
                                     'mvName' value m.mview_name,
                                     'priority' value nvl(p.priority, 0)) 
                         order by p.priority desc nulls last)
      into v_json_obj
      from user_mviews m
      left join mv_priorities p
        on m.owner = p.owner
       and m.mview_name = p.mv_name
       and p.active = 1;
  
    po_json_object := v_json_obj;
  exception
    when no_data_found then
      po_json_object := null;
  end get_mv_list_with_priorities;

  procedure save_mv_priority(p_owner           in varchar2,
                             p_mv_name         in varchar2,
                             p_priority_number in number) as
    v_count integer;
  begin
    select count(1)
      into v_count
      from mv_priorities p
     where p.owner = p_owner
       and p.mv_name = p_mv_name
       and p.active = 1;
  
    if v_count = 0 then
      insert into mv_priorities
        (owner, mv_name, priority, active, first_time)
      values
        (p_owner, p_mv_name, p_priority_number, 1, systimestamp);
    else
      update mv_priorities
         set priority = p_priority_number, last_time = systimestamp
       where owner = p_owner
         and mv_name = p_mv_name
         and active = 1;
    end if;
    
    commit;
  end save_mv_priority;

  procedure delete_mv_priority(p_owner in varchar2, p_mv_name in varchar2) as
    v_count integer;
  begin
    update mv_priorities
       set active = 0, last_time = systimestamp
     where owner = p_owner
       and mv_name = p_mv_name
       and active = 1;
       
    commit;
  end delete_mv_priority;

  procedure set_action_time(p_session_id in raw,
                            p_owner      in varchar2,
                            p_mv_name    in varchar2,
                            p_start_time in timestamp,
                            p_end_time   in timestamp,
                            p_err_msg    in varchar2 default null) is
    pragma autonomous_transaction;
  begin
    update mv_refresh_log
       set start_time = nvl(p_start_time, start_time),
           end_time = nvl(p_end_time, end_time),
           err_msg = p_err_msg
     where session_id = p_session_id
       and owner = p_owner
       and mv_name = p_mv_name;
  
    commit;
  end;

  procedure make_mv_log_rec(p_session_id in raw,
                            p_owner      in varchar2,
                            p_mv_name    in varchar2,
                            p_priority   in number,
                            p_path       in varchar2) is
    pragma autonomous_transaction;
    v_count integer;
  begin
    select count(1)
      into v_count
      from mv_refresh_log
     where session_id = p_session_id
       and owner = p_owner
       and mv_name = p_mv_name
       and start_time is null
       and end_time is null;
  
    if v_count = 0 then
      insert into mv_refresh_log
        (session_id, owner, mv_name, start_time, end_time, err_msg, priority, dependency_path)
      values
        (p_session_id, p_owner, p_mv_name, null, null, null, p_priority, p_path);
    end if;

    commit;
  end make_mv_log_rec;

  procedure refresh_mv(p_session_id in raw, p_owner in varchar2, p_mv_name in varchar2) is
    v_start_time timestamp;
  begin
    v_start_time := systimestamp;
    
    set_action_time(p_session_id => p_Session_id,
                    p_owner      => p_owner,
                    p_mv_name    => p_mv_name,
                    p_start_time => v_start_time,
                    p_end_time   => null,
                    p_err_msg    => null);
    
    --ar oracle 12.2 sakot pec MV refresha ar atomic_refresh = false (tiek veikts trunc table) mums vairs nevaig no jauna uzstadit indexus un savakt statistiku, tas viss notiek automatiski
    --kad MV refresh tiek sakts, tad indexi, kas piesaistiti MV paliek statusa unusable, bet pec MV refresh tiek tiek automatiski atkal atjaunoti un savakta statistika
    dbms_mview.refresh(list => p_owner || '.' || p_mv_name, METHOD => 'C', ATOMIC_REFRESH => false);
  
    set_action_time(p_session_id => p_Session_id,
                    p_owner      => p_owner,
                    p_mv_name    => p_mv_name,
                    p_start_time => v_start_time,
                    p_end_time   => systimestamp,
                    p_err_msg    => null);
    
    --izsaucam proceduru, kas atradis nakamo pieejamo prioritaro MV un iesedules tam jobu MV refresham
    get_next_mv(p_session_id);
  exception
    when others then
      v_start_time := systimestamp;
    
      set_action_time(p_session_id => p_Session_id,
                      p_owner      => p_owner,
                      p_mv_name    => p_mv_name,
                      p_start_time => v_start_time,
                      p_end_time   => systimestamp,
                      p_err_msg    => sqlerrm);
                      
      get_next_mv(p_session_id);
  end refresh_mv;

  procedure schedule_mv_refresh_job(p_Session_id in raw,
                                    p_owner      in varchar2,
                                    p_mv_name    in varchar2) is
    v_start_time timestamp;
  begin
    --iesedulejam jobu, kas saks darbu uzreiz
    --jobs veiks MV refresh un izsauks proceduru, kas atradis nakamo pieejamo prioritaro MV un atkal schedules jobu lai tiktu veikts refresh
    dbms_scheduler.create_job(job_name   => 'REFRESH_MV_' || p_mv_name || '_' || p_Session_id,
                              job_type   => 'PLSQL_BLOCK',
                              job_action => 'BEGIN '||
                                            '  administer_mv_pck.refresh_mv(''' || p_Session_id || ''',''' || p_owner || ''',''' || p_mv_name || '''); '||
                                            'END;',
                              start_date => sysdate,
                              enabled    => true,
                              auto_drop  => false);

  exception
    when others then
      v_start_time := systimestamp;
    
      set_action_time(p_session_id => p_Session_id,
                      p_owner      => p_owner,
                      p_mv_name    => p_mv_name,
                      p_start_time => v_start_time,
                      p_end_time   => systimestamp,
                      p_err_msg    => sqlerrm);
                      
      get_next_mv(p_session_id);
  end schedule_mv_refresh_job;

  --procedura mekle 
  procedure find_deepest_dependency_mv(p_session_id in raw,
                                       p_owner      in varchar2,
                                       p_mv_name    in varchar2,
                                       pio_owner    in out varchar2,
                                       pio_mv_name  in out varchar2,
                                       pio_path     in out varchar2) is
    v_owner             MV_REFRESH_LOG.owner%type;
    v_mv_name           MV_REFRESH_LOG.mv_name%type;
    v_tmp_owner         MV_REFRESH_LOG.owner%type;
    v_tmp_mv_name       MV_REFRESH_LOG.mv_name%type;
    
    cursor c_find_deepest_dependency_mv is
    select referenced_owner, referenced_name
      from user_dependencies
     where name = p_mv_name
       and dependency_type = 'REF'
       and referenced_type = 'MATERIALIZED VIEW'
       and not exists (select 1
                         from MV_REFRESH_LOG l
                        where l.session_id = p_session_id 
                          and l.owner = referenced_owner
                          and l.mv_name = referenced_name);
  begin
    open c_find_deepest_dependency_mv;
    fetch c_find_deepest_dependency_mv into v_owner, v_mv_name;

    if c_find_deepest_dependency_mv%FOUND then
      if pio_path is null then
        pio_path := p_owner || '.' || p_mv_name || '/' || v_owner || '.' || v_mv_name;
      else
        pio_path := pio_path || '/' || v_owner || '.' || v_mv_name;
      end if;
      
      pio_owner   := v_owner;
      pio_mv_name := v_mv_name;
    
      find_deepest_dependency_mv(p_session_id => p_session_id,
                                 p_owner      => v_owner,
                                 p_mv_name    => v_mv_name,
                                 pio_owner    => pio_owner,
                                 pio_mv_name  => pio_mv_name,
                                 pio_path     => pio_path);
    end if;
    
    close c_find_deepest_dependency_mv;
  end find_deepest_dependency_mv;

  procedure get_next_mv(p_session_id in raw) is
    v_owner       MV_REFRESH_LOG.owner%type;
    v_mv_name     MV_REFRESH_LOG.mv_name%type;
    v_tmp_owner   MV_REFRESH_LOG.owner%type;
    v_tmp_mv_name MV_REFRESH_LOG.mv_name%type;
    v_priority    mv_refresh_log.priority%type;
    v_path        MV_REFRESH_LOG.dependency_path%type;
    
    cursor c_next_available_mv is
    select m.owner, m.mview_name, p.priority
      from user_mviews m
      left join mv_priorities p
        on m.owner = p.owner
       and m.mview_name = p.mv_name
       and p.active = 1
     where not exists (select 1
              from mv_refresh_log l
             where l.session_id = p_session_id
               and l.owner = m.owner
               and l.mv_name = m.mview_name)
       and not exists (select 1
                         from mv_refresh_log l
                         join user_dependencies d
                           on l.owner = d.referenced_owner
                          and l.mv_name = d.referenced_name
                        where l.session_id = p_session_id
                          and l.end_time is null
                          and d.dependency_type = 'REF'
                          and d.referenced_type = 'MATERIALIZED VIEW'
                          and d.name = m.mview_name)
     order by p.priority desc nulls last;
  begin
    open c_next_available_mv;
    fetch c_next_available_mv into v_owner, v_mv_name, v_priority;
    
    --ja nekas netika atrasts tas nozime, ka vairs nav MV ko nepieciesams refresot, varam beigt darbu
    if c_next_available_mv%FOUND then
      find_deepest_dependency_mv(p_session_id => p_session_id,
                                 p_owner      => v_owner,
                                 p_mv_name    => v_mv_name,
                                 pio_owner    => v_tmp_owner,
                                 pio_mv_name  => v_tmp_mv_name,
                                 pio_path     => v_path);
  
      if v_tmp_mv_name is not null then
        make_mv_log_rec(p_session_id => p_session_id,
                        p_owner      => v_tmp_owner,
                        p_mv_name    => v_tmp_mv_name,
                        p_priority   => v_priority,
                        p_path       => v_path);
      else
        make_mv_log_rec(p_session_id => p_session_id,
                        p_owner      => v_owner,
                        p_mv_name    => v_mv_name,
                        p_priority   => v_priority,
                        p_path       => null);
      end if;
      
      schedule_mv_refresh_job(p_session_id, nvl(v_tmp_owner, v_owner), nvl(v_tmp_mv_name, v_mv_name));
    end if;
    
    close c_next_available_mv;
  end get_next_mv;

  procedure prepare_mv_for_refresh(p_session_id          in raw,
                                   p_parallel_flow_count in number) is
    v_owner         MV_REFRESH_LOG.owner%type;
    v_mv_name       MV_REFRESH_LOG.mv_name%type;
    v_tmp_owner     MV_REFRESH_LOG.owner%type;
    v_tmp_mv_name   MV_REFRESH_LOG.mv_name%type;
    v_path          MV_REFRESH_LOG.dependency_path%type;
    v_do_mv_refresh BOOLEAN := FALSE;
    v_count         INTEGER;
  begin
    --tik cik plusmas tik pamata ierakstus saglabajam
    for i in 1 .. p_parallel_flow_count loop
      for mv_rec in (select m.owner, m.mview_name, p.priority
                       from user_mviews m
                       left join mv_priorities p
                         on m.owner = p.owner
                        and m.mview_name = p.mv_name
                        and p.active = 1
                      where not exists (select 1
                                          from MV_REFRESH_LOG l
                                         where l.session_id = p_session_id
                                           and l.owner = m.owner
                                           and l.mv_name = m.mview_name)
                      order by p.priority desc nulls last) loop
        v_tmp_owner     := null;
        v_tmp_mv_name   := null;
        v_path          := null;

        --parbaudam vai prioritarajam MV neeksiste dependent MV, kuri butu jarefresho pirmie
        find_deepest_dependency_mv(p_session_id => p_session_id,
                                   p_owner      => mv_rec.owner,
                                   p_mv_name    => mv_rec.mview_name,
                                   pio_owner    => v_tmp_owner,
                                   pio_mv_name  => v_tmp_mv_name,
                                   pio_path     => v_path);

        --ja dependency MV nav atrasts uzstadam to view name kas bija mv_rec kursora atrasts
        if v_tmp_mv_name is null then
          v_tmp_owner   := mv_rec.owner;
          v_tmp_mv_name := mv_rec.mview_name;
        end if;

        select count(1)
          into v_count
          from user_mviews m
         where m.owner = v_tmp_owner 
           and m.mview_name = v_tmp_mv_name
           and not exists (select 1
                             from mv_refresh_log l
                            where l.session_id = p_session_id
                              and l.owner = m.owner
                              and l.mv_name = m.mview_name)
           and not exists (select 1
                             from mv_refresh_log l
                             join user_dependencies d
                               on l.owner = d.referenced_owner
                              and l.mv_name = d.referenced_name
                            where l.session_id = p_session_id
                              and l.end_time is null
                              and d.dependency_type = 'REF'
                              and d.referenced_type = 'MATERIALIZED VIEW'
                              and d.name = m.mview_name);

        if v_count > 0 then
          make_mv_log_rec(p_session_id => p_session_id,
                          p_owner      => v_tmp_owner,
                          p_mv_name    => v_tmp_mv_name,
                          p_priority   => mv_rec.priority,
                          p_path       => v_path);
          
          --ieplanojam MV refresh jobu
          --sis job refreshos konkreto MV un ieplanos nakama MV refreshu pec prioritates
          schedule_mv_refresh_job(p_session_id,
                                  v_tmp_owner,
                                  v_tmp_mv_name);
          
          --ejam ara no mv_rec LOOPa, parejam uz nakamo plusmu, kur tiks ieplanots MV refresham                        
          exit;
        end if;
      end loop;
    end loop;
  end;

  --atkariba no ta cik nodefinets ir p_parallel_flow_count tik daudz paralelos jobus ieschedulesim lai refreshotu MV
  --primari tiek refreshoti tie MV kuriem ir augstaka prioritate
  --ja MV ko gribam refreshot ir dependend MV, kas vel nav refreshots, tad sakuma to refreshojam un tad tikai turpinam refreshot esoso MV
  procedure refresh_all_mv(p_parallel_flow_count integer) is
    v_session_id mv_refresh_log.session_id%type;
  begin
    v_session_id := sys_guid();
  
    --sagatavo katras plusmas pirmo atjauninamo MV
    prepare_mv_for_refresh(p_session_id          => v_session_id,
                           p_parallel_flow_count => p_parallel_flow_count);
  end refresh_all_mv;

end administer_mv_pck;
/