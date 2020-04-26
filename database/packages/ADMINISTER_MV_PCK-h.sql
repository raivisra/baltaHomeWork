create or replace package ADMINISTER_MV_PCK as
  --iegust JSON objekta, kas paredzets backend un satures sarakstu ar visiem MV un pieskirtajam prioritatem
  procedure get_mv_list_with_priorities(po_json_object out varchar); 
  
  procedure get_mv_log_data(po_json_object out varchar);
  
  --saglabajam konkretajam MV prioritati
  procedure save_mv_priority(p_owner           in varchar2,
                             p_mv_name         in varchar2,
                             p_priority_number in number);

  --dzesam prioritates vertibu, kas pieskirta MV
  procedure delete_mv_priority(p_owner in varchar2, p_mv_name in varchar2);

  procedure refresh_all_mv(p_parallel_flow_count integer);

  procedure refresh_mv(p_session_id in raw, p_owner in varchar2, p_mv_name in varchar2);

end ADMINISTER_MV_PCK;
/