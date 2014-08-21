require 'rubygems'
require 'bundler/setup'
Bundler.require
require 'erb'

LIBREOFFICE = "\"C:\\Program Files (x86)\\LibreOffice 4\\program\\soffice.exe\" --headless --invisible"
OUTPUT = "C:\\Pris\\reports"
$db_user = 'sa'
$db_password = 'ofc6302'

#LIBREOFFICE = "C:\\PortableApps\\PortableApps\\LibreOfficePortable\\LibreOfficePortable.exe --headless --invisible"
#OUTPUT = "C:\\Temp\\Report"
#$db_user = 'sa'
#$db_password = 'sa2010'

def get_conn
  return $conn if $conn!=nil
  puts "create connection..."
  $conn = TinyTds::Client.new(:username => $db_user, :password => $db_password, :host => 'hqsvr2', :database => 'hq', :timeout => 600)
  #required for distributied query
  $conn.execute("SET ANSI_NULLS ON")
  $conn.execute("SET ANSI_WARNINGS ON")
  return $conn
end

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
end

module TinyTds
  class Client
    def remote_execute(store, sql)
      sql = "#{store}.PRIS.dbo.sp_executesql N'#{sql.gsub("'", "''")}'"
      #puts sql
      return self.execute(sql)
    end
    
    def execute_batch(sqls)
      sqls.split(';').each do |sql|
        #puts sql
        self.execute(sql).do
      end
    end
  end
  
  class Result
    def to_insert_scripts(tbl_name, clear=true)
      if clear then
        sqls = "delete from #{tbl_name};"
      else
        sqls=''
      end
      
      self.each do |r|
        sql = "INSERT Into #{tbl_name} ("
        r.each do |k, v|
          sql = sql+"#{k},"
        end
        sql = sql.chop + ') values('
        
        r.each do |k, v|
          if v.class == String then
            sql = sql+"'#{v}',"
          else
            sql = sql+"#{v},"
          end
        end
        
        sql = sql.chop + ');'
        sqls =sqls + sql
      end
      #puts sqls
      return sqls
    end
    
    def to_s
      strs=''
      self.each do |r|
        str = ""
        r.each do |k, v|
          str = str+"#{k}\t"
        end
        str = str.chop + "\n"
        r.each do |k, v|
          str = str+"#{v}\t"
        end
        str = str.chop + "\n"
        strs =strs + str
      end
      #puts strs
      return strs
    end
  end  
end

def read_data_sql(store, dt, ws)
  conn = get_conn
  data = {'Store' => store, 'Date' => dt, 'ws' => ws, 'print_at' => Time.now.strftime("%Y/%m/%d %H:%M:%S")}
  data['Date'].gsub!('-', '/')

  result = conn.execute("SELECT Name, Value FROM rpt_2z where Store='#{store}'")
  result.each do |row|
    if row['Name'] == 'STANDARD_TC1' then
      data['COMP_HOMEPAGE'] = row['Value'] 
    else
      data[row['Name']] = row['Value']
    end
  end

  result = conn.execute("SELECT Emp, Method, PayAmt FROM rpt_2a where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  payment = {'ALL'=>{'Emp'=>'ALL', 'List'=>{}}}
  cash_amount = 0
  debit_amount = 0
  credit_amount = 0
  total_payment = 0
  result.each do |row|
    if payment[row['Emp']] == nil then
      payment[row['Emp']] = {} 
      payment[row['Emp']]['Emp'] = row['Emp']
      payment[row['Emp']]['List'] = {}
    end
    payment[row['Emp']]['List'][row['Method']] = {'Method'=>"#{row['Method']}", 'PayAmt'=>row['PayAmt']}
    
    payment['ALL']['List'][row['Method']] = {'Method'=>"#{row['Method']}", 'PayAmt'=>0} if payment['ALL']['List'][row['Method']] == nil
    payment['ALL']['List'][row['Method']]['PayAmt'] = payment['ALL']['List'][row['Method']]['PayAmt'] + row['PayAmt']
    
    cash_amount = cash_amount + row['PayAmt'] if row['Method']=='Cash'
    debit_amount = debit_amount + row['PayAmt'] if row['Method']=='Debit'
    credit_amount = credit_amount + row['PayAmt'] if row['Method']=='Credit'
    total_payment = total_payment + row['PayAmt']
  end
  data['cash_amount'] = cash_amount
  data['debit_amount'] = debit_amount
  data['credit_amount'] = credit_amount
  data['charge_amount'] = 0
    #SHOULD INCLUDE COUPON, REPLICATE THE ERROR IN POS
  data['total_payment'] = data['cash_amount'] + data['debit_amount'] + data['credit_amount']
  
   result = conn.execute("SELECT Cashier, PayOut FROM rpt_2b where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  result.each do |row|
    payment[row['Cashier']]['List']['Payout'] = {'Method'=>'PayOut', 'PayAmt' => -row['PayOut']}
    
    payment['ALL']['List']['Payout'] = {'Method'=>'PayOut', 'PayAmt' => 0} if payment['ALL']['List']['Payout'] == nil
    payment['ALL']['List']['Payout']['PayAmt'] = payment['ALL']['List']['Payout']['PayAmt'] - row['PayOut']
  end

  data['Payout'] = payment['ALL']['List']['Payout']==nil ? 0.0 : payment['ALL']['List']['Payout']['PayAmt']
  data['Payout'] = -data['Payout'] if data['Payout'] != 0
  
  data['cash_in_drawer'] = data['cash_amount'] - data['Payout']
  data['total_in_drawer'] = data['cash_in_drawer'] + data['debit_amount'] + data['credit_amount']
 
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
      array << {'Method'=>'', 'PayAmt' =>  "--------------"}
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
    p['Emp'] = 'CASHER:   ' + p['Emp']
  end
  data['Payment'] << all if data['Payment'].length > 1
  
  result = conn.execute("SELECT RetailSales, Five_Cent_Round FROM rpt_2c where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  data['RetailSales'] = 0.0
  data['Five_Cent_Round']
  result.each do |row|
    data['RetailSales'] = row['RetailSales'] if row['RetailSales'] != nil
    data['Five_Cent_Round'] = row['Five_Cent_Round'] if row['Five_Cent_Round'] != nil
    data['Five_Cent_Round'] = -data['Five_Cent_Round'] if data['Five_Cent_Round'] != 0
  end
  
  result = conn.execute("SELECT Coupon FROM rpt_2g where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  data['Coupon'] = 0.0
  result.each do |row|
    data['Coupon'] = row['Coupon'] if row['Coupon'] != nil
  end
  
  data['RetailSales'] = data['RetailSales'] - data['Coupon']

puts "SELECT Num_Of_Txn, Convert(Varchar, [Start_Time], 108) Start_Time, Tax1, Tax2 FROM rpt_2d where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'"
  result = conn.execute("SELECT Num_Of_Txn, Convert(Varchar, [Start_Time], 108) Start_Time, Tax1, Tax2 FROM rpt_2d where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  data['Tax1'] = 0.0
  data['Tax2'] = 0.0
  result.each do |row|
    data['Num_Of_Txn'] = row['Num_Of_Txn']
    data['Start_Time'] = row['Start_Time']
    data['Tax1'] = row['Tax1'] if row['Tax1']!=nil
    data['Tax2'] = row['Tax2'] if row['Tax2']!=nil
  end  

  data['NetSales'] = data['RetailSales']+data['Five_Cent_Round']-data['Tax1']-data['Tax2']

  result = conn.execute("SELECT First_Emp, print_at, print_by FROM rpt_2e where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  result.each do |row|
    data['First_Emp'] = row['First_Emp']
    data['print_by'] = row['print_by']
    data['print_at'] = row['print_at'].strftime("%Y/%m/%d %H:%M:%S")
  end

  result = conn.execute("SELECT Net_Sales, Tax_1, Tax_2, Total_Sales FROM rpt_2h where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  result.each do |row|
    data['Net_Sales'] = row['Net_Sales']
    data['Tax_1'] = row['Tax_1']
    data['Tax_2'] = row['Tax_2']
    data['Total_Sales'] = row['Total_Sales']
  end

  result = conn.execute("SELECT Emp, Action, Affected_Items,Affected_Amt FROM rpt_2f where Store='#{store}' and Dt='#{dt}' and WS='#{ws}'")
  actions = {}
  deleted_count = 0
  deleted_amount = 0
  refund_count = 0
  refund_amount = 0
  void_count = 0
  void_amount = 0
  discount_count = 0
  discount_amount = 0
  
  result.each do |row|
    actions[row['Emp']] = {'Emp'=>row['Emp'], 'ActionList'=>{}} if actions[row['Emp']] == nil
    actions[row['Emp']]['ActionList']["#{row['Action']}_Amt"] = row['Affected_Amt']
    actions[row['Emp']]['ActionList']["#{row['Action']}_Items"] = row['Affected_Items']
    
    if row['Action'] == 'Delete' then
      deleted_count = deleted_count + row['Affected_Items'] 
      deleted_amount = deleted_amount + row['Affected_Amt'] 
    end
    if row['Action'] == 'Refund' then
      refund_count = refund_count + row['Affected_Items'] 
      refund_amount = refund_amount + row['Affected_Amt'] 
    end
    if row['Action'] == 'Void' then
      void_count = void_count + row['Affected_Items'] 
      void_amount = void_amount + row['Affected_Amt'] 
    end
    if row['Action'] == 'Discount' then
      discount_count = discount_count + row['Affected_Items'] 
      discount_amount = discount_amount + row['Affected_Amt'] 
    end
  end
  refund_amount = -refund_amount if refund_amount != 0
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
  data['delete_count'] = deleted_count
  data['delete_amount'] = deleted_amount
  data['refund_count'] = refund_count
  data['refund_amount'] = refund_amount
  data['void_count'] = void_count
  data['void_amount'] = void_amount
  data['discount_count'] = discount_count
  data['discount_amount'] = discount_amount

  data['avg_txn_amt'] = data['RetailSales'] / data['Num_Of_Txn']
  data['Num_Of_Txn'] = data['Num_Of_Txn'].to_s
  data.deep_traverse do |k, v|
    if v.class == Float or v.class == BigDecimal then
      v = number_to_string(v)
    end
    if v.class == Fixnum then
      v = "%.2f" % v
    end
    v
  end
#puts data

  return data
end

def write_data_file(store, dt, ws)
  data = read_data_sql(store, dt, ws)
  f = File.open("#{store}_#{dt.gsub('/', '_')}_#{ws}.json", 'w')
  f.puts data.to_json
  f.close
end

def read_data_file(store, dt, ws)
  return JSON.parse(File.read("#{store}_#{dt.gsub('/', '_')}_#{ws}.json"))
end

def download_data(store, dt)
  result = get_conn.remote_execute(store, "Select '#{store}' Store, FieldID Name, FieldValue Value From [PM].[MBPOSDB].[dbo].[SystemParm] Where FieldID In ('COMP_HOMEPAGE','COMP_PHONE_AREA','COMP_PHONE_NUM','COMP_STREET','COMP_CITY','COMP_PROV','COMP_POS','GST NUMBER','COMP_TITLE','STANDARD_TC1')")
  get_conn.execute_batch(result.to_insert_scripts("rpt_2z"))
  
  result = get_conn.remote_execute(store, "Select '#{store}' Store, '#{dt}' Dt, WorkStationID WS, EmpNum Emp, Method, Sum(PayAmt) PayAmt From [PM].[MBPOSDB].[dbo].InvPay Where PayDate = '#{dt}' Group By WorkStationID, EmpNum, Method")
  get_conn.execute_batch(result.to_insert_scripts("rpt_2a"))

  result = get_conn.remote_execute(store, "Select '#{store}' Store, '#{dt}' Dt, WSID WS, Cashier, Sum(LineAmt) PayOut From [PM].[MBPOSDB].[dbo].PayOut Where PayDate = '#{dt}' Group By WSID, Cashier")
  get_conn.execute_batch(result.to_insert_scripts("rpt_2b"))


  result = get_conn.remote_execute(store, "Select '#{store}' Store, '#{dt}' Dt, WorkStationID WS, Sum(PayAmt) RetailSales, Sum(PaymentDiscount) Five_Cent_Round From [PM].[MBPOSDB].[dbo].InvPay Where PayDate = '#{dt}' Group By WorkStationID")
  get_conn.execute_batch(result.to_insert_scripts("rpt_2c"))

  result = get_conn.remote_execute(store, "Select '#{store}' Store, '#{dt}' Dt, Ship_Dest WS, Count(*) Num_Of_Txn, Convert(Varchar, Min(InvoiceTime), 108) Start_Time, Sum(Tax1) Tax1, Sum(Tax2) Tax2 From [PM].[MBPOSDB].[dbo].Invoice Where Date_Sent = '#{dt}' Group By Ship_Dest")
  get_conn.execute_batch(result.to_insert_scripts("rpt_2d"))

  result = get_conn.remote_execute(store, "Select '#{store}' Store, '#{dt}' Dt, A.Ship_Dest WS, A.Emp_Num First_Emp From [PM].[MBPOSDB].[dbo].Invoice A Join (Select SHIP_DEST, Min(InvoiceTime) Tm from [PM].[MBPOSDB].[dbo].Invoice Where Date_Sent = '#{dt}' Group By SHIP_DEST) B On A.SHIP_DEST = B.SHIP_DEST And A.InvoiceTime = B.Tm")
  get_conn.execute_batch(result.to_insert_scripts("rpt_2e"))

  result = get_conn.remote_execute(store, "Select '#{store}' Store, '#{dt}' Dt, WS, OperatorID Emp, Action=CASE [Action] WHEN '1' THEN 'Delete' WHEN '2' THEN 'Refund' WHEN '3' THEN 'Void' WHEN '9' THEN 'Discount' END, Count(*) Affected_Items, Sum(Affected_Amt) Affected_Amt From [PM].[MBPOSDB].[dbo].ActionLog Where Act_Date = '#{dt}' Group By WS, OperatorID, Action")
  get_conn.execute_batch(result.to_insert_scripts("rpt_2f"))
  
  result = get_conn.remote_execute(store, "Select '#{store}' Store, '#{dt}' Dt, WorkStationID WS, Sum(PayAmt) Coupon From [PM].[MBPOSDB].[dbo].InvPay Where Method='Coupon' And PayDate = '#{dt}' Group By WorkStationID")
  get_conn.execute_batch(result.to_insert_scripts("rpt_2g"))
end

def log(id, str)
  get_conn.execute("update report_queue set log = log + CHAR(13) + CHAR(10) + '#{str}' where id = #{id};").do
end

def row(left, right, n=50)
	return "#{left}#{' '*(n - left.length - right.length)}#{right}"
end

def generate_report(store, dt, ws, tp, id)
  get_conn.execute("update rpt_2e set status = 'running', run_at = GetDate() where id = #{id};").do
  log(id, "start at #{Time.now}")
  
    log(id, "reading start at #{Time.now}")
    d = read_data_sql(store, dt, ws)
    #write_data_file(store, dt, ws)
    #data = read_data_file(store, dt, ws)
    #puts JSON.pretty_generate(data)
    
    if tp=='Report' then
	    log(id, "merge report for #{ws} at #{Time.now}")
	    template = "summary.odt"
	    report = JODFReport::Report.new(template, d)
	    report_file = report.generate
	    
	    ws_report_file = report_file.gsub(/([^\/]*).odt$/, "\\1_#{store}_#{dt.gsub('/', '_')}_#{ws}.odt")
	    #puts "#{report_file}-->#{ws_report_file}"
	    FileUtils.mv(report_file, ws_report_file)
	    
	    log(id, "generate pdf for #{ws} at #{Time.now}")
	    cmd = "#{LIBREOFFICE} --convert-to pdf #{ws_report_file} --outdir #{OUTPUT}"
	    `#{cmd}`
    elsif tp=='Receipt'
        template = ERB.new File.read('summary.erb')
	ws_report_file = "#{OUTPUT}\\#{store}_#{dt.gsub('/', '_')}_#{ws}.txt"
	puts ws_report_file
	f = File.open(ws_report_file, "w")
	f.puts template.result(binding)
	f.close
	`PosPrint.exe PosPrinter #{ws_report_file}`
    end
    
  log(id, "finished at #{Time.now}")
  
  get_conn.execute("update rpt_2e set status = 'completed', completed_at = GetDate() where id = #{id};").do
end

def start_job
  while (true) do
    store = nil
    dt = nil
    ws = nil
    id =  nil
    tp = nil
    result = get_conn.execute("select top 1 * from rpt_2e where status = 'waiting' order by submitted_at;")
    
    result.each do |r|
      store = r['Store']
      dt = r['Dt']
      ws = r['WS']
      tp = r['type']
      id = r['id']
    end
    break if result.affected_rows == 0
    generate_report(store, dt, ws, tp, id)
  end
end

start_job
