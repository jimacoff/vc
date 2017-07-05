module Internal::CompaniesHelper
  def company_class(company)
    if company.funded?
      'success'
    elsif company.passed?
      'danger'
    elsif company.pitched?
      'warning'
    elsif !company.pitch.blank?
      'info'
    else
      'muted'
    end
  end
end
