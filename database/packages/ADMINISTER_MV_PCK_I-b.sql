create or replace package body administer_mv_i as

  procedure get_mv_log_data(po_json_object out varchar) as
    v_json_object_list varchar2(4000);
  begin
    --saucam implementacijas pakotni
    administer_mv_pck.get_mv_log_data(po_json_object => v_json_object_list);
    po_json_object := v_json_object_list;
  end get_mv_log_data;
  
  procedure get_mv_list_with_priorities(po_json_object out varchar2) as
    v_json_object_list varchar2(4000);
  begin
    --saucam implementacijas pakotni
    administer_mv_pck.get_mv_list_with_priorities(po_json_object => v_json_object_list);
    po_json_object := v_json_object_list;
  end get_mv_list_with_priorities;

  procedure save_mv_priority(p_owner           in varchar2,
                             p_mv_name         in varchar2,
                             p_priority_number in number) as
  begin
    --saucam implementacijas pakotni
    administer_mv_pck.save_mv_priority(p_owner           => p_owner,
                                       p_mv_name         => p_mv_name,
                                       p_priority_number => p_priority_number);
  end save_mv_priority;

  procedure delete_mv_priority(p_owner in varchar2, p_mv_name in varchar2) as
  begin
    --saucam implementacijas pakotni
    administer_mv_pck.delete_mv_priority(p_owner => p_owner, p_mv_name => p_mv_name);
  end delete_mv_priority;

  procedure refresh_all_mv(p_parallel_flow_count integer) is
  begin
    administer_mv_pck.refresh_all_mv(p_parallel_flow_count => p_parallel_flow_count);
  end refresh_all_mv;

end administer_mv_i;
/