require 'rubygems'
require 'bundler/setup'
Bundler.require

LIBREOFFICE = "C:\\PortableApps\\PortableApps\\LibreOfficePortable\\LibreOfficePortable.exe --headless --invisible"
OUTPUT = "C:\\Temp\\Report"

def number_to_string(n)
    s = "%.2f" % n
    while s.sub!(/(\d+)(\d\d\d)/,'\1,\2'); end
    s
end

def string_to_number(s)
  return s.gsub(',', '').to_f
end

class String
  def to_currency
    string_to_number(self)
  end
end

class Float
  def currency
    number_to_string(self)
  end
end

class Fixnum
  def currency
    number_to_string(self)
  end
end

class BigDecimal
  def currency
    number_to_string(self)
  end
end

class Hash
  def deep_traverse(&block)
    self.each do |k, v|
      if v.class == Array then
        v.each do |vm|
          vm.deep_traverse(&block)
        end
      elsif v.class == Hash then
        v.deep_traverse(&block)
      else
        self[k] = yield(k, v)
      end
    end
  end
  
  def deep_merge!(other_hash)
    other_hash.each_pair do |k,v|
      tv = self[k]
      self[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? tv.deep_merge(v) : v
    end
    self
  end
  
  def deep_merge(other_hash)
    dup.deep_merge!(other_hash)
  end  
end

class TinyTds::Client
  def remote_execute(store, sql)
    sql = "#{store}.PRIS.dbo.sp_executesql N'#{sql.gsub("'", "''")}'"
    #puts sql
    return self.execute(sql)
  end
end

def get_conn
  return $conn if $conn!=nil
  puts "create connection..."
  $conn = TinyTds::Client.new(:username => 'sa', :password => 'sa2010', :host => 'localhost', :database => 'hq', :timeout => 600)
  #required for distributied query
  $conn.execute("SET ANSI_NULLS ON")
  $conn.execute("SET ANSI_WARNINGS ON")
  return $conn
end

def read_data_sql(store, dt, ws)
  conn = get_conn
  data = {'Store' => store, 'Date' => dt, 'ws' => ws, 'print_at' => Time.now.strftime("%Y/%m/%d at %H:%M:%S")}

  result = conn.execute("SELECT Name, Value FROM rpt_2z where Store='#{store}'")
  result.each do |row|
    data[row['Name']] = row['Value']
  end

  result = conn.execute("SELECT Emp, Method, PayAmt FROM rpt_2a where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  payment = {'ALL'=>{'Emp'=>'ALL', 'List'=>{}}}
  result.each do |row|
    if payment[row['Emp']] == nil then
      payment[row['Emp']] = {} 
      payment[row['Emp']]['Emp'] = row['Emp']
      payment[row['Emp']]['List'] = {}
    end
    payment[row['Emp']]['List'][row['Method']] = {'Method'=>"#{row['Method']}", 'PayAmt'=>row['PayAmt']}
    
    payment['ALL']['List'][row['Method']] = {'Method'=>"#{row['Method']}", 'PayAmt'=>0} if payment['ALL']['List'][row['Method']] == nil
    payment['ALL']['List'][row['Method']]['PayAmt'] = payment['ALL']['List'][row['Method']]['PayAmt'] + row['PayAmt']
  end
  
  result = conn.execute("SELECT Cashier, PayOut FROM rpt_2b where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  result.each do |row|
    payment[row['Cashier']]['List']['Payout'] = {'Method'=>'PayOut', 'PayAmt' => -row['PayOut']}
    
    payment['ALL']['List']['Payout'] = {'Method'=>'PayOut', 'PayAmt' => 0} if payment['ALL']['List']['Payout'] == nil
    payment['ALL']['List']['Payout']['PayAmt'] = payment['ALL']['List']['Payout']['PayAmt'] - row['PayOut']
  end

  data['Payout'] = payment['ALL']['List']['Payout']==nil ? 0.0 : payment['ALL']['List']['Payout']['PayAmt']

  payment.each do |k, v|
    list = v['List']
    
    if list['Payout'] != nil then
      list['Net Cash'] = {'Method'=>'Net Cash', 'PayAmt' => list['Cash']['PayAmt'] + list['Payout']['PayAmt']}
      list['Sales Cash'] = {'Method'=>'Sales Cash', 'PayAmt' => list['Cash']['PayAmt']}
      list.delete('Cash')
    else
      if list['Cash'] != nil then
        list['Net Cash'] = {'Method'=>'Net Cash', 'PayAmt' => list['Cash']['PayAmt']}
      else
        list['Net Cash'] = {'Method'=>'Net Cash', 'PayAmt' => 0}
      end
    end
    
    v['Total'] = list['Net Cash']['PayAmt']
    v['Total'] = v['Total'] + list['Debit']['PayAmt'] if list['Debit'] != nil
    v['Total'] = v['Total'] + list['Credit']['PayAmt'] if list['Credit'] != nil
    v['Total'] = v['Total']
    
    array = []
    array << {'Method'=>'Sales Cash', 'PayAmt'=>list['Sales Cash']['PayAmt']} if list['Sales Cash'] != nil
    if list['Payout'] != nil then
      array << {'Method'=>'Pay Out', 'PayAmt'=>list['Payout']['PayAmt']}
      array << {'Method'=>'', 'PayAmt' =>  "--------"}
    end
    array << {'Method'=>'Net Cash', 'PayAmt'=>list['Net Cash']['PayAmt']} if list['Net Cash'] != nil    
    array << {'Method'=>'Net Debit', 'PayAmt'=>list['Debit']['PayAmt']} if list['Debit'] != nil
    array << {'Method'=>'Net Credit', 'PayAmt'=>list['Credit']['PayAmt']} if list['Credit'] != nil
    
    v['List'] = array
  end

  all = payment.delete('ALL')
  all['Emp'] = 'SUMMARY:      ALL'
  
  data['Payment'] = payment.values
  data['Payment'].each do |p|
    p['Emp'] = 'CASHER:      ' + p['Emp']
  end
  data['Payment'] << all
  
  result = conn.execute("SELECT RetailSales, Five_Cent_Round FROM rpt_2c where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  result.each do |row|
    data['RetailSales'] = row['RetailSales']
    data['Five_Cent_Round'] = row['Five_Cent_Round']
  end

  result = conn.execute("SELECT Num_Of_Txn, Convert(Varchar, [Start_Time], 108) Start_Time, Tax1, Tax2 FROM rpt_2d where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  result.each do |row|
    data['Num_Of_Txn'] = row['Num_Of_Txn'].to_s
    data['Start_Time'] = row['Start_Time']
    data['Tax1'] = row['Tax1']
    data['Tax2'] = row['Tax2']
  end  

  data['NetSales'] = data['RetailSales']+data['Five_Cent_Round']-data['Tax1']-data['Tax2']

  result = conn.execute("SELECT First_Emp FROM rpt_2e where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  result.each do |row|
    data['First_Emp'] = row['First_Emp']
  end

  result = conn.execute("SELECT Emp, Action, Affected_Items,Affected_Amt FROM rpt_2f where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  actions = {}
  result.each do |row|
    actions[row['Emp']] = {'Emp'=>row['Emp'], 'ActionList'=>{}} if actions[row['Emp']] == nil
    actions[row['Emp']]['ActionList']["#{row['Action']}_Amt"] = row['Affected_Amt']
    actions[row['Emp']]['ActionList']["#{row['Action']}_Items"] = row['Affected_Items']
  end
  
  actions.each do |k, v|
    al = []
    al << {'Name'=>'Delete Items', 'Value'=> v['ActionList']['Delete_Items'] == nil ? 0 : v['ActionList']['Delete_Items']}
    al << {'Name'=>'Delete Amt', 'Value'=> v['ActionList']['Delete_Amt'] == nil ? 0.0 : v['ActionList']['Delete_Amt']}
    al << {'Name'=>'Refund Items', 'Value'=> v['ActionList']['Refund_Items'] == nil ? 0 : v['ActionList']['Refund_Items']}
    al << {'Name'=>'Refund Amt', 'Value'=> v['ActionList']['Refund_Amt'] == nil ? 0.0 : v['ActionList']['Refund_Amt']}
    al << {'Name'=>'Void Items', 'Value'=> v['ActionList']['Void_Items'] == nil ? 0 : v['ActionList']['Void_Items']}
    al << {'Name'=>'Void Amt', 'Value'=> v['ActionList']['Void_Amt'] == nil ? 0.0 : v['ActionList']['Void_Amt']}
    al << {'Name'=>'Disc Txns', 'Value'=> v['ActionList']['Discount_Items'] == nil ? 0 : v['ActionList']['Discount_Items']}
    al << {'Name'=>'Disc Amt', 'Value'=> v['ActionList']['Discount_Amt'] == nil ? 0.0 : v['ActionList']['Discount_Amt']}
    v['ActionList'] = al
  end
  data['Actions'] = actions.values

  data.deep_traverse do |k, v|
    if v.class == Float or v.class == BigDecimal then
      v = number_to_string(v)
    end
    v
  end
  
  return data
end

def write_data_file(data)
  store = data['Store']
  dt = data['Date']
  f = File.open("#{store}_#{dt.gsub('/', '_')}.json", 'w')
  f.puts data.to_json
  f.close
end

def read_data_file(store, dt)
  return JSON.parse(File.read("#{store}_#{dt.gsub('/', '_')}.json"))
end

def generate_report(store, dt, ws)
  puts "generating reports for #{store} at #{dt} for #{ws}"
  data = read_data_sql(store, dt, ws)
  #write_data_file(store, dt, ws)
  #data = read_data_file(store, dt, ws)
  #puts JSON.pretty_generate(data)

  template = "summary.odt"
  report = JODFReport::Report.new(template, data)
  report_file = report.generate
  
  ws_report_file = report_file.gsub(/([^\/]*).odt$/, "\\1_#{store}_#{dt.gsub('/', '_')}_#{ws}.odt")
  #puts "#{report_file}-->#{ws_report_file}"
  FileUtils.mv(report_file, ws_report_file)
  
  #cmd = "#{LIBREOFFICE} \"#{report_file}\""
  #`#{cmd}`
  cmd = "#{LIBREOFFICE} --convert-to pdf #{ws_report_file} --outdir #{OUTPUT}"
  `#{cmd}`
end

def remote_execute(conn, store, sql)
  #result = conn.execute("Select WorkStationID WS, EmpNum Emp, Method, Sum(PayAmt) PayAmt From [PM].[MBPOSDB].[dbo].InvPay Where PayDate = '#{dt}' Group By WorkStationID, EmpNum, Method")
  
  sql = "#{store}.PRIS.dbo.sp_executesql N'#{sql.gsub("'", "''")}'"
  puts sql
  result = conn.execute(sql)
  
  return result
end


def hashnize(result, args)
  fds = result.fields - args
  h = {}
  result.each do |r|
    hs = h
    args.each do |k|
      hs[r[k]] = {} if hs[r[k]] == nil  
      hs = hs[r[k]]
    end
    fds.each do |fd|
      hs[fd] = r[fd]
    end
  end  
  return h
end

def collect_data(store, dt)
  data = {'Store' => store, 'Date' => dt, 'Print_At' => Time.now.strftime("%Y/%m/%d at %H:%M:%S")}

  result = get_conn.remote_execute(store, "Select FieldID Name, FieldValue Value From [PM].[MBPOSDB].[dbo].[SystemParm] Where FieldID In ('COMP_HOMEPAGE','COMP_PHONE_AREA','COMP_PHONE_NUM','COMP_STREET','COMP_CITY','COMP_PROV','COMP_POS','GST_NUMBER','COMP_TITLE')")
  data.deep_merge!(hashnize(result, ['Name']))
puts data

  wss = data['WSs']  
  result = get_conn.remote_execute(store, "Select WorkStationID WS, EmpNum Emp, Method, Sum(PayAmt) PayAmt From [PM].[MBPOSDB].[dbo].InvPay Where PayDate = '#{dt}' Group By WorkStationID, EmpNum, Method")
  x = hashnize(result, ['WS', 'Emp', 'Method'])
  data.deep_merge!(x)
  puts x
  
  data.deep_merge!(hashnize(result, ['Name']))
  payment = {'ALL'=>{'Emp'=>'ALL', 'List'=>{}}}
  result.each do |r|
    wss[r['WS']] = {} if wss[r['WS']] == nil
    ws = wss[r['WS']]
    ws[r['Emp']] = {}  if ws[r['Emp']] == nil
    emp = ws[r['Emp']]
    emp[r['Method']] = r['PayAmt'] if emp[r['Method']] == nil
  end

  result = get_conn.remote_execute(store, "Select WSID WS, Cashier, Sum(PayTotal) PayOut From [PM].[MBPOSDB].[dbo].PayOut Where PayDate = '#{dt}' Group By WSID, Cashier")
  result.each do |r|
    wss[r['WS']] = {} if wss[r['WS']] == nil
    ws = wss[r['WS']]
    ws[r['Cashier']] = {} if ws[r['Cashier']] == nil
    ws[r['Cashier']]['Payout'] = r['PayOut']
  end
  
  result = get_conn.remote_execute(store, "Select WorkStationID WS, Sum(PayAmt) RetailSales, Sum(PaymentDiscount) Five_Cent_Round From [PM].[MBPOSDB].[dbo].InvPay Where PayDate = '#{dt}' Group By WorkStationID")
  result.each do |r|
    wss[r['WS']] = {} if wss[r['WS']] == nil
    ws = wss[r['WS']]
    ws['RetailSales'] = r['RetailSales']
    ws['Five_Cent_Round'] = r['Five_Cent_Round']
  end

  result = get_conn.remote_execute(store, "Select Ship_Dest WS, Count(*) Num_Of_Txn, Convert(Varchar, Min(InvoiceTime), 108) Start_Time, Sum(Tax1) Tax1, Sum(Tax2) Tax2 From [PM].[MBPOSDB].[dbo].Invoice Where Date_Sent = '#{dt}' Group By Ship_Dest")
  result.each do |r|
    wss[r['WS']] = {} if wss[r['WS']] == nil
    ws = wss[r['WS']]
    ws['Num_Of_Txn'] = r['Num_Of_Txn'].to_s
    ws['Start_Time'] = r['Start_Time']
    ws['Tax1'] = r['Tax1']
    ws['Tax2'] = r['Tax2']
  end  

  result = get_conn.remote_execute(store, "Select A.Ship_Dest WS, A.Emp_Num First_Emp From [PM].[MBPOSDB].[dbo].Invoice A Join (Select SHIP_DEST, Min(InvoiceTime) Tm from [PM].[MBPOSDB].[dbo].Invoice Where Date_Sent = '#{dt}' Group By SHIP_DEST) B On A.SHIP_DEST = B.SHIP_DEST And A.InvoiceTime = B.Tm")
  result.each do |r|
    wss[r['WS']] = {} if wss[r['WS']] == nil
    ws = wss[r['WS']]
    ws['First_Emp'] = r['First_Emp']
  end  

  result = get_conn.remote_execute(store, "Select WS, OperatorID Emp, Action=CASE [Action] WHEN '1' THEN 'Delete' WHEN '2' THEN 'Refund' WHEN '3' THEN 'Void' WHEN '9' THEN 'Discount' END, Count(*) Affected_Items, Sum(Affected_Amt) Affected_Amt From [PM].[MBPOSDB].[dbo].ActionLog Where Act_Date = '#{dt}' Group By WS, OperatorID, Action")
  wss1 = hashnize(result, ['WS', 'Emp', 'Action'])

wss.deep_merge!(wss1)

  return data
end

def format_data(data)
  data.deep_traverse do |k, v|
    if v.class == Float or v.class == BigDecimal then
      v = number_to_string(v)
    end
    v
  end
  return data
end

def generate_reports(store, dt)
  puts "generating reports for #{store} at #{dt}"
  data = collect_data(store, dt)
  data = format_data(data)
  write_data_file(data)
  data = read_data_file(store, dt)
  puts JSON.pretty_generate(data)

  
  #conn = get_conn
  #result = conn.execute("EXEC Create_Report2_Data @STORE='#{store}', @Dt='#{dt}'")
  #result.each do |row|
    #generate_report(store, dt, row['WS'])
  #end
end

#if ARGV.length==2 then
#  generate_reports(ARGV[0], ARGV[1])
#else
#  puts "#{$0} STORE DATE"
#end

#l = File.read('reports_to_be_generated')
#store, dt = l.split(' ')
#generate_reports(store, dt)

generate_reports('ALP', '2014/01/04')



