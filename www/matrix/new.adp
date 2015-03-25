<master src="../../../intranet-core/www/master">

<property name="title">#intranet-translation.Trados_Matrix#</property>
<property name="context">#intranet-translation.context#</property>
<property name="main_navbar_label">finance</property>

<property name="focus">@focus;noquote@</property>


<form action=new-2 method=POST>
@export_vars;noquote@
<table border=0>
<tr>
  <td class=rowtitle align=middle>
    #intranet-translation.Trados_Matrix#
  </td>
  <td class=rowtitle align=middle>
    #intranet-translation.Trans#
  </td>
  <td class=rowtitle align=middle>
    #intranet-translation.Edit#
  </td>
  <td class=rowtitle align=middle>
    #intranet-translation.Proof#
  </td>
</tr>
<tr>
  <td>#intranet-translation.X_Trans#</td>
  <td><input type=text name=trans_match_x size=8 value=@trans_match_x@></td>
  <td><input type=text name=edit_match_x size=8 value=@edit_match_x@></td>
  <td><input type=text name=proof_match_x size=8 value=@proof_match_x@></td>  
</tr>
<tr>
  <td>#intranet-translation.Repetitions#</td>
  <td><input type=text name=trans_match_rep size=8 value=@trans_match_rep@></td>
  <td><input type=text name=edit_match_rep size=8 value=@edit_match_rep@></td>
  <td><input type=text name=proof_match_rep size=8 value=@proof_match_rep@></td>
</tr>

<tr>
  <td><%= [lang::message::lookup "" intranet-translation.Perf "Perfect Match"] %></td>
  <td><input type=text name=trans_match_perf size=8 value=@trans_match_perf@></td>
  <td><input type=text name=edit_match_perf size=8 value=@edit_match_perf@></td>
  <td><input type=text name=proof_match_perf size=8 value=@proof_match_perf@></td>
</tr>
<tr>
  <td><%= [lang::message::lookup "" intranet-translation.Cfr "Cross File Repetitions"] %></td>
  <td><input type=text name=trans_match_cfr size=8 value=@trans_match_cfr@></td>
  <td><input type=text name=edit_match_cfr size=8 value=@edit_match_cfr@></td>
  <td><input type=text name=proof_match_cfr size=8 value=@proof_match_cfr@></td>
</tr>
<tr>
  <td><%= [lang::message::lookup "" intranet-translation.Locked "Locked"] %></td>
  <td><input type=text name=trans_locked size=8 value=@trans_locked@></td>
  <td><input type=text name=edit_locked size=8 value=@edit_locked@></td>
  <td><input type=text name=proof_locked size=8 value=@proof_locked@></td>
</tr>

<tr>
  <td>100%</td>
  <td><input type=text name=trans_match100 size=8 value=@trans_match100@></td>
  <td><input type=text name=edit_match100 size=8 value=@edit_match100@></td>
  <td><input type=text name=proof_match100 size=8 value=@proof_match100@></td>
</tr>
<tr>
  <td>95% - 99%</td>
  <td><input type=text name=trans_match95 size=8 value=@trans_match95@></td>
  <td><input type=text name=edit_match95 size=8 value=@edit_match95@></td>
  <td><input type=text name=proof_match95 size=8 value=@proof_match95@></td>
</tr>
<tr>
  <td>85% - 94%</td>
  <td><input type=text name=trans_match85 size=8 value=@trans_match85@></td>
  <td><input type=text name=edit_match85 size=8 value=@edit_match85@></td>
  <td><input type=text name=proof_match85 size=8 value=@proof_match85@></td>
</tr>
<tr>
  <td>75% - 84%</td>
  <td><input type=text name=trans_match75 size=8 value=@trans_match75@></td>
  <td><input type=text name=edit_match75 size=8 value=@edit_match75@></td>
  <td><input type=text name=proof_match75 size=8 value=@proof_match75@></td>
</tr>
<tr>
  <td>50% - 74%</td>
  <td><input type=text name=trans_match50 size=8 value=@trans_match50@></td>
  <td><input type=text name=edit_match50 size=8 value=@edit_match50@></td>
  <td><input type=text name=proof_match50 size=8 value=@proof_match50@></td>
</tr>
<tr>
  <td>#intranet-translation.No_Match#</td>
  <td><input type=text name=trans_match0 size=8 value=@trans_match0@></td>
  <td><input type=text name=edit_match0 size=8 value=@edit_match0@></td>
  <td><input type=text name=proof_match0 size=8 value=@proof_match0@></td>
</tr>

<tr>
  <td><%= [lang::message::lookup "" intranet-translation.Same_File_Fuzzy "Same File Fuzzy Matches"] %> 95% - 99%</td>
  <td><input type=text name=trans_match_f95 size=8 value=@trans_match_f95@></td>
  <td><input type=text name=edit_match_f95 size=8 value=@edit_match_f95@></td>
  <td><input type=text name=proof_match_f95 size=8 value=@proof_match_f95@></td>
</tr>
<tr>
  <td><%= [lang::message::lookup "" intranet-translation.Same_File_Fuzzy "Same File Fuzzy Matches"] %> 85% - 94%</td>
  <td><input type=text name=trans_match_f85 size=8 value=@trans_match_f85@></td>
  <td><input type=text name=edit_match_f85 size=8 value=@edit_match_f85@></td>
  <td><input type=text name=proof_match_f85 size=8 value=@proof_match_f85@></td>
</tr>
<tr>
  <td><%= [lang::message::lookup "" intranet-translation.Same_File_Fuzzy "Same File Fuzzy Matches"] %> 75% - 84%</td>
  <td><input type=text name=trans_match_f75 size=8 value=@trans_match_f75@></td>
  <td><input type=text name=edit_match_f75 size=8 value=@edit_match_f75@></td>
  <td><input type=text name=proof_match_f75 size=8 value=@proof_match_f75@></td>
</tr>
<tr>
  <td><%= [lang::message::lookup "" intranet-translation.Same_File_Fuzzy "Same File Fuzzy Matches"] %> 50% - 74%</td>
  <td><input type=text name=trans_match_f50 size=8 value=@trans_match_f50@></td>
  <td><input type=text name=edit_match_f50 size=8 value=@edit_match_f50@></td>
  <td><input type=text name=proof_match_f50 size=8 value=@proof_match_f50@></td>
</tr>

<tr>
  <td colspan=2 align=middle>
    <input type=submit value=Save>
  </td>
</tr>
</table>
</form>


