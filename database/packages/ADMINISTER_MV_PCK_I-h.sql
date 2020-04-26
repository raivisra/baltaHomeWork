create or replace package administer_mv_i as
  /*
  Interfeisa pakotne, kas paredzeta lai izsauktu ADMINISTER_MV_PCK
  Taisits tiri prieks backend vajadzibam.
  Backendam nav vajadzibas pieklut pa tieso galvenas pakotnes kodam.
  Turklat Interfeisa pakotni varesi grantot tiem kam bus vajadziba/tiesibas to izmantot
  */

  procedure get_mv_log_data(po_json_object out varchar);
  
  --iegust JSON objekta, kas paredzets backend un satures sarakstu ar visiem MV un pieskirtajam prioritatem
  procedure get_mv_list_with_priorities(po_json_object out varchar2);

  --saglabajam konkretajam MV prioritati
  procedure save_mv_priority(p_owner           in varchar2,
                             p_mv_name         in varchar2,
                             p_priority_number in number);

  --dzesam prioritates vertibu, kas pieskirta MV
  procedure delete_mv_priority(p_owner in varchar2, p_mv_name in varchar2);

  --refreshojam MV
  procedure refresh_all_mv(p_parallel_flow_count integer);
end administer_mv_i;
/
